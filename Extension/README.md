# Safari Extension API

The library itself is a part of the [SafariConverterLib] project that is
responsible for interpreting AdGuard rules and applying them to web pages.

The output of the [SafariConverterLib] is a set of rules that can be used in
the browser extension in two different ways:

1. As a set of rules for Safari content blocker. In this case Safari
   takes care of applying the rules to the web page.
2. As a set of "advanced" rules that can be used either in a
   [Safari Web Extension][SafariWebExtension] or a [Safari App Extension][SafariAppExtension].
   In either case, the rules are interpreted by the Javascript that runs in the
   browser extension. This library provides the API for the Javascript to
   interpret the rules and apply them to the web page.

[SafariConverterLib]: https://github.com/AdguardTeam/SafariConverterLib
[SafariWebExtension]: https://developer.apple.com/documentation/safariservices/safari-web-extensions
[SafariAppExtension]: https://developer.apple.com/documentation/safariservices/safari-app-extensions

## How to use the library

The library provides a set of classes that can be used to interpret the rules
and apply them to the web page.

The main class is [Configuration]. It is used to configure the
library and to get the rules that should be applied to the web page. This class
has the following fields:

- `css` - a set of CSS rules (selector + style) that will be used to apply
  additional styles to the elements on a page.
- `extendedCss` - a set of CSS rules that will be used to apply additional
  styles to the elements on a page via Extended CSS library.
- `js` - a set of JS scripts that will be executed on the page.
- `scriptlets` - a set of scriptlets parameters that will be used to run
  "scriptlets" on the page. Scriptlets implementations are provided by the
  [Scriptlets] library.
- `engineTimestamp` - the timestamp of the engine that was used to generate
  the configuration. This can be used to determine if the configuration is
  outdated and needs to be updated.

[Scriptlets]: https://github.com/AdguardTeam/Scriptlets
[Configuration]: src/configuration.ts

## Usage

Add dependency:

```json
"dependencies": {
  "package-name": "github:user/repo#tag"
}
```

Request the rules from a background page (use WebExtension as an example):

Content script:

```ts
const response = await browser.runtime.sendMessage(message);
```

Background page:

```ts
browser.runtime.onMessage.addListener(async (request: unknown) => {
    // Cast the incoming request as a Message.
    const message = request as Message;

    // Extract the URL from the message payload.
    const { url } = message.payload as { url: string };

    // Send the request to the native messaging host and wait for the response.
    const response = await browser.runtime.sendNativeMessage('application.id', request);
    const message = response as ResponseMessage;

    // Extract the URL from the request payload.
    const { url } = request.payload as { url: string };
    // Extract the configuration from the response payload.
    const configuration = message.payload as Configuration;

    // If the engine timestamp has been updated, clear the cache and update
    // the timestamp.
    if (configuration.engineTimestamp !== engineTimestamp) {
        cache.clear();
        engineTimestamp = configuration.engineTimestamp;
    }

    // Save the new message in the cache for the given URL.
    cache.set(url, message);
})
```

TODO(ameshkov): !!! Add usage examples here.

## How to build the library

```sh
pnpm install
pnpm build
```

TODO(ameshkov): !!! Explain every command here.
