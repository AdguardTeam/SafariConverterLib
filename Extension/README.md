# Safari Extension API

- [Build Instructions](#build-instructions)
- [How does it work](#how-does-it-work)
- [How to use the library](#how-to-use-the-library)
    - [Host app](#host-app)
    - [Safari Web Extension](#safari-web-extension)
        - [Web Extension's Content Script](#web-extensions-content-script)
        - [Web Extension's Background Script](#web-extensions-background-script)
        - [Web Extension's Native Host](#web-extensions-native-host)
    - [Safari App Extension](#safari-app-extension)
        - [App Extension's Content Script](#app-extensions-content-script)
        - [App Extension's Native Host](#app-extensions-native-host)

The library itself is part of the [SafariConverterLib] project that is
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

## Build Instructions

- `pnpm install` - install dependencies.
- `pnpm build` - build the `dist` directory.
- `pnpm lint` - run linter.
- `pnpm test` - run tests.

## How does it work

The library provides a set of classes that can be used to interpret the rules
and apply them to the web page.

The main class is [Configuration]. It is used to configure the library and to
get the rules that should be applied to the web page.

It is mapped to an instance of [WebExtension.Configuration] which should be
passed from the extension's native host to the content script.

This object is then interpreted either by [ContentScript] or [BackgroundScript]
depending on the extension type (it will be explained below).

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

[Scriptlets]: https://github.com/AdguardTeam/Scriptlets
[Configuration]: src/configuration.ts
[ContentScript]: src/content-script.ts
[BackgroundScript]: src/background-script.ts
[WebExtension.Configuration]: ../Sources/FilterEngine/WebExtension.swift

## How to use the library

The way the library is used depends on whether it is used in a [Safari App Extension][SafariAppExtension]
or a [Safari Web Extension][SafariWebExtension].

In the explanation below, we will be using the following terms you need to
familiarize yourself with:

- "Host app" - the app that hosts the extension. This is the app that the user
  will actually run.
- "Extension native host" - the app that hosts the Web Extension's or the
  App Extension's native code. It can share files with the "Host app" using app
  groups.
- "Background page" - the browser extension's background page (written in JS).
  Runs in the extension’s own context, separate from the web pages, there's
  only one instance of it. **Only exists in a Web Extension**.
- "Content script" - the browser extension's content script (written in JS).
  Runs in the context of the web page.

See the full example here or read below:

- [Web Extension's native host][webextnativehost]
- [Web Extension's javascript][webextjavascript]
- [App Extension's native host][appextnativehost]
- [App Extension's content script][appextcontentscript]

[webextnativehost]: https://github.com/ameshkov/safari-blocker/tree/master/web-extension
[webextjavascript]: https://github.com/ameshkov/safari-blocker/tree/master/extensions/webext
[appextnativehost]: https://github.com/ameshkov/safari-blocker/tree/master/app-extension
[appextcontentscript]: https://github.com/ameshkov/safari-blocker/tree/master/extensions/appext

### Host app

The main prerequisite is that you first need to figure out which AdGuard rules
are counted as "advanced" and which can be used natively by Safari. You can read
how to do that in the [project README.md](../README.md).

Once you have the advanced rules, use them **in your Host app** to build the
filtering engine that the extension will use for doing lookups. This is done by
using this code:

```swift
let webExtension = try WebExtension.shared(groupID: "your.group.id")

// Build the engine and serialize it to the shared location.
_ = try webExtension.buildFilterEngine(rules: advancedRulesText)
```

### Javascript code

Start with adding the library as a dependency to your extension code:

```sh
npm add -i @adguard/safari-extension
```

Logger can be redefined by the library user or you can use `ConsoleLogger` class
that is provided by the library. Use `setLogger` to set the logger that will
be used:

```ts
import { setLogger, ConsoleLogger, LoggingLevel } from '@adguard/safari-extension';

setLogger(new ConsoleLogger('[Safari Extension]', LoggingLevel.Info));
```

### Safari Web Extension

In the case of [Safari Web Extension][SafariWebExtension], there's a background
page and we can use the `browser.scripting` API to inject JS and CSS to avoid the
risk of being blocked by the website's CSP.

However, due to [a bug in Safari Web Extension][bugexecutescript], we have to use
the fallback approach for `about:blank` and `about:srcdoc` frames. Hopefully,
this will be resolved in the future.

[bugexecutescript]: https://bugs.webkit.org/show_bug.cgi?id=296702

#### Web Extension's Content Script

Make sure that the content script is configured to run on all pages including
iframes. Below is an example of how the content script should be registered in
`manifest.json`:

```json
    "content_scripts": [
        {
            "js": [
                "content.js"
            ],
            "matches": [
                "<all_urls>"
            ],
            "run_at": "document_start",
            "all_frames": true,
            "match_about_blank": true,
            "match_origin_as_fallback": true
        }
    ]
```

The very first step would be to expose `ContentScript` to other content scripts;
this way it can be called from scripts injected by `scripting.executeScript()`.

```ts
// First of all, make sure that the content script is exposed to the
// scripts that will be called by background script.
window.adguard = {
    contentScript: new ContentScript(),
};
```

The second thing is to delay native load events:

```js
// Initialize the delayed event dispatcher. This may intercept DOMContentLoaded
// and load events. The delay of 1000ms is used as a buffer to capture critical
// initial events while waiting for the rules response.
const cancelDelayedDispatchAndDispatch = setupDelayedEventDispatcher(1000);
```

Finally, request configuration from the background page:

```js
const main = async () => {
    const message = {
        type: 'lookup',
    };

    // Send the message to the background script and await the response.
    const response = await browser.runtime.sendMessage(message);

    // If the background page returned payload with configuration, it means
    // that it cannot apply it on its own and commands the content script
    // to do that.
    if (response?.payload) {
        window.adguard.contentScript.applyConfiguration(response?.payload);
    }

    // After processing, cancel any pending delayed event dispatch and process
    // any queued events immediately.
    cancelDelayedDispatchAndDispatch();
};

// Execute the main function and catch any runtime errors.
main().catch((error) => {
    console.error('Error in content script: ', error);
});
```

#### Web Extension's Background Script

On the background page, you should listen for incoming messages and relay them
to the native host. In addition to that, we strongly recommend having a local
cache on the background page to speed up lookups.

```js
import browser from 'webextension-polyfill';
import { type Configuration, BackgroundScript } from '@adguard/safari-extension';

/**
 * BackgroundScript is used to apply filtering configuration to web pages.
 * Note that it relies on the content script to be injected into the page
 * and available in the ISOLATED world via the `adguard.contentScript` object.
 */
const backgroundScript = new BackgroundScript();

browser.runtime.onMessage.addListener(async (message, sender) => {
    if (message.type === 'lookup') {
        // Extract the URL from the sender data.
        const tabId = sender.tab?.id ?? 0;
        const frameId = sender.frameId ?? 0;
        let blankFrame = false;

        let url = sender.url || '';
        const topUrl = frameId === 0 ? undefined : sender.tab?.url;

        if (!url.startsWith('http') && topUrl) {
            // Handle the case of non-HTTP iframes, i.e., frames created by JS.
            // For instance, frames can be created as 'about:blank' or 'data:text/html'.
            url = topUrl;
            blankFrame = true;
        }

        const lookupMessage = {
            type: 'lookup',
            url,
            topUrl,
        };

        // Ask the native host to lookup rules for the given URL and top-level URL.
        const response = await browser.runtime.sendNativeMessage('application.id', lookupMessage);

        // In the current Safari version, we cannot apply rules to blank frames from
        // the background: https://bugs.webkit.org/show_bug.cgi?id=296702
        //
        // In this case, we fall back to using the content script to apply rules.
        // The downside here is that the content script cannot override the website's
        // CSPs.
        if (!blankFrame && response.payload) {
            await backgroundScript.applyConfiguration(
                tabId,
                frameId,
                response.payload,
            );
        }

        // Pass the configuration to the content script.
        return response;
    }
});
```

### Web Extension's Native Host

Finally, in the native host code, you should handle the message and use
`WebExtension` to look up the configuration.

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

        if type == "lookup" {
            do {
                guard let urlString = message["url"] as? String else {
                    return
                }
                let topUrlString = message["topUrl"] as? String

                guard let url = URL(string: urlString) else {
                    return
                }

                let topUrl = URL(string: topUrlString ?? "")

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
        payload["engineTimestamp"] = configuration.engineTimestamp

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

### Safari App Extension

In the case of [Safari App Extension][SafariAppExtension], there's no background
page and all rule types are interpreted by [ContentScript].

Add the library as a dependency to your extension code:

```sh
npm add -i @adguard/safari-extension
```

#### App Extension's Content Script

In the content script request the rules from the native host:

```js
// Generate a pseudo-unique request ID for properly tracing the response to the
// request that was sent by this instance of an SFSafariContentScript.
// We will only accept responses to this specific request.
const requestId = Math.random().toString(36);

// Prepare the message to request configuration rules for the current page.
// getUrl() and getTopUrl() need to be implemented (see safari-blocker for an
// example).
const message = {
    requestId,
    url: getUrl(),
    topUrl: getTopUrl(),
};

// Dispatch the "requestRules" message to the Safari extension.
safari.extension.dispatchMessage('requestRules', message);
```

You also need to handle the response from the native host and pass the
[Configuration] object to [ContentScript]:

```js
import {
    type Configuration,
    ContentScript,
    setupDelayedEventDispatcher
} from '@adguard/safari-extension';

// Initialize the delayed event dispatcher. This may intercept DOMContentLoaded
// and load events. The delay of 1000ms is used as a buffer to capture critical
// initial events while waiting for the rules response.
const cancelDelayedDispatchAndDispatch = setupDelayedEventDispatcher(1000);

// Register the event listener for incoming messages from the extension.
safari.self.addEventListener('message', handleMessage);

const handleMessage = (event) => {
    const message = event.message;

    if (message?.requestId !== requestId) {
        // Received response for a different request ID; ignore it as it
        // was sent to a different frame.

        return;
    }

    // If the configuration payload exists, run the ContentScript with it.
    if (message?.payload) {
        new ContentScript().applyConfiguration(message?.payload);
    }

    // Cancel the pending delayed event dispatch and process any queued events.
    cancelDelayedDispatchAndDispatch();
};
```

#### App Extension's Native Host

Finally, in the extension's native host code, you should handle the message and
use `WebExtension` to look up the configuration.

```swift
public override func messageReceived(
    withName messageName: String,
    from page: SFSafariPage,
    userInfo: [String: Any]?
) {
    // Skip code

    let webExtension = try WebExtension.shared(
        groupID: GroupIdentifier.shared.value
    )

    if let conf = webExtension.lookup(pageUrl: url, topUrl: topUrl) {
        // Convert the configuration into a payload (dictionary
        // format) that is consumable by the content script.
        let payload = convertToPayload(conf)

        // Dispatch the payload back to the web page under the same
        // message name.
        let responseUserInfo: [String: Any] = [
            "requestId": requestId,
            "payload": payload,
        ]

        page.dispatchMessageToScript(
            withName: "requestRules",
            userInfo: responseUserInfo
        )
    }
}
```
