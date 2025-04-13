# Safari Extension API

The library itself is a part of the [SafariConverterLib] project that is
responsible for interpreting AdGuard rules and applying them to web pages.

The output of the [SafariConverterLib] is a set of rules that can be used in
the browser extension in two different ways:

1. As a set of rules for Safari content blocker. In this case, Safari
   takes care of applying the rules to the web page.
2. As a set of "advanced" rules that can be used either in a
   [Safari Web Extension][SafariWebExtension] or a [Safari App Extension][SafariAppExtension].
   In either case, the rules are interpreted by the JavaScript that runs in the
   browser extension. This library provides the API for the JavaScript to
   interpret the rules and apply them to the web page.

This library provides the API to interpret "advanced rules" and is supposed to
be used from a browser extension's content script.

[SafariConverterLib]: https://github.com/AdguardTeam/SafariConverterLib
[SafariWebExtension]: https://developer.apple.com/documentation/safariservices/safari-web-extensions
[SafariAppExtension]: https://developer.apple.com/documentation/safariservices/safari-app-extensions

## How does it work

The library provides a set of classes that can be used to interpret the rules
and apply them to the web page.

The main class is [Configuration]. It is used to configure the library and to
get the rules that should be applied to the web page.

It is mapped to an instance of [WebExtension.Configuration] which should be
passed from the extension's native host to the content script.

This class has the following fields:

- `css` - a set of CSS rules (selector + style) that will be used to apply
  additional styles to the elements on a page.
- `extendedCss` - a set of CSS rules that will be used to apply additional
  styles to the elements on a page via Extended CSS library.
- `js` - a set of JS scripts that will be executed on the page.
- `scriptlets` - a set of scriptlet parameters that will be used to run
  "scriptlets" on the page. Scriptlet implementations are provided by the
  [Scriptlets] library.
- `engineTimestamp` - the timestamp of the engine that was used to generate
  the configuration. This can be used to determine if the configuration is
  outdated and needs to be updated.

Configuration can then be interpreted by [ContentScript]:

```ts
new ContentScript(config).run();
```

[Scriptlets]: https://github.com/AdguardTeam/Scriptlets
[Configuration]: src/configuration.ts
[ContentScript]: src/content-script.ts
[WebExtension.Configuration]: ../Sources/FilterEngine/WebExtension.swift

## How to use the library

We will be using [Safari Web Extension][SafariWebExtension] as an example.
You can also check out the [safari-blocker][safariblocker] app for a more
complete example.

In the explanation below, we will be using the following terms you need to
familiarize yourself with:

- "Host app" - the app that hosts the extension. This is the app that the user
  will actually run.
- "Extension native host" - the app that hosts the Web Extension's native code.
  It can share files with the "Host app" using app groups.
- "Background page" - the browser extension's background page (written in JS).
  Runs in the extension’s own context, separate from the web pages, there's
  only one instance of it.
- "Content script" - the browser extension's content script (written in JS).
  Runs in the context of the web page.

### Host app

The main prerequisite is that you first need to figure out which AdGuard rules are
counted as "advanced" and which can be used natively by Safari, you can read
how to do that in the [project README.md](../README.md).

Once you have the advanced rules, use them **in your Host app** to build the
filtering engine which the extension will use for doing lookups. It is done by
using this code.

```swift
let webExtension = try WebExtension.shared(groupID: "your.group.id")

// Build the engine and serialize it to the shared location.
_ = try webExtension.buildFilterEngine(rules: advancedRulesText)
```

### Javascript (Background page and content script)

Add the library as a dependency to your extension code:

```sh
npm add -i @adguard/safari-extension
```

In the content script, you will need to request the rules from a background page:

```ts
import browser from 'webextension-polyfill';
import { type Configuration, ContentScript } from '@adguard/safari-extension';

const main = async () => {
    // Request configuration for the current page from the background script.
    const message = {
        type: "lookup",
    };

    const response = await browser.runtime.sendMessage(message);

    if (response) {
        // Extract the payload from the response, which contains the configuration.
        const { configuration, verbose } = response as {
            configuration: Configuration;
            verbose: boolean;
        };

        // Instantiate and run the content script with the provided configuration.
        new ContentScript(configuration).run(verbose, '[Web Extension]');
    }
}

main().catch((error) => {
    console.error('Error in the content script: ', error);
});
```

On the background page you should listen for incoming messages and pass them
to the native host. In addition to that we strongly recommend having a local
cache on the background page to speed up lookups.

```ts
import browser from 'webextension-polyfill';
import { type Configuration } from '@adguard/safari-extension';

browser.runtime.onMessage.addListener(async (request: unknown, sender: unknown) => {
    // Cast the incoming request as a Message.
    const message = request as { type: string };

    if (message.type === 'lookup') {
        // Extract the URL from the sender data.
        const senderData = sender as { url: string, frameId: number, tab: { url: string } };
        const { url } = senderData;
        const topUrl = senderData.frameId === 0 ? null : senderData.tab.url;

        const lookupMessage = {
            type: 'lookup',
            url,
            topUrl,
        };

        // Ask the native host to lookup rules for the given URL and top-level URL.
        const response = await browser.runtime.sendNativeMessage('application.id', lookupMessage);

        const responseMessage = response as {
            configuration: Configuration,
            verbose: boolean
        };

        return responseMessage;
    }
});
```

### Extension native host

Finally, in the native host code, you should handle the message and use
WebExtension to look up the configuration.

**IMPORTANT:** You need to replace `your.group.id` with your own group ID.

```swift
import FilterEngine
import SafariServices
import os.log

public class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    public func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message = getMessage(from: request)

        guard let message = message,
              let type = message["type"] as? String
        else {
            return
        }

        var responseMessage: [String: Any] = [:]

        // Enable verbose logging in the content script.
        // In the real app `verbose` flag should only be true for debugging purposes.
        responseMessage["verbose"] = true

        if type == "lookup" {
            do {
                guard let urlString = message["url"] as? String else {
                    return
                }
                let topUrlString = message["topUrl"] as? String

                guard let url = URL(string: urlString) else {
                    return
                }

                var topUrl: URL?
                if let topUrlString = topUrlString {
                    topUrl = URL(string: topUrlString)
                }

                let webExtension = try WebExtension.shared(
                    groupID: "your.group.id"
                )

                if let configuration = webExtension.lookup(pageUrl: url, topUrl: topUrl) {
                    responseMessage["configuration"] = convertToDictionary(configuration)
                }
            } catch {
                os_log(
                    .error,
                    "Failed to get WebExtension instance: %@",
                    error.localizedDescription
                )
            }
        }

        context.completeRequest(
            returningItems: [createResponse(with: responseMessage)],
            completionHandler: nil
        )
    }

    private func convertToDictionary(
        _ configuration: WebExtension.Configuration
    ) -> [String: Any] {
        var payload: [String: Any] = [:]
        payload["css"] = configuration.css
        payload["extendedCss"] = configuration.extendedCss
        payload["js"] = configuration.js

        var scriptlets: [[String: Any]] = []
        for scriptlet in configuration.scriptlets {
            var scriptletData: [String: Any] = [:]
            scriptletData["name"] = scriptlet.name
            scriptletData["args"] = scriptlet.args
            scriptlets.append(scriptletData)
        }

        payload["scriptlets"] = scriptlets

        return payload
    }

    private func createResponse(with json: [String: Any?]) -> NSExtensionItem {
        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: json]
        } else {
            response.userInfo = ["message": json]
        }

        return response
    }

    private func getMessage(from request: NSExtensionItem?) -> [String: Any?]? {
        if request == nil {
            return nil
        }

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        if message is [String: Any?] {
            return message as? [String: Any?]
        }

        return nil
    }
}
```

[safariblocker]: https://github.com/ameshkov/safari-blocker

## Build Instructions

- `pnpm install` - install dependencies.
- `pnpm build` - build the `dist` directory.
- `pnpm lint` - run linter.
- `pnpm test` - run tests.
