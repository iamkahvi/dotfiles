// Finicky v4 config: https://github.com/johnste/finicky/wiki/Configuration-(v4)
// Source: https://vault.shopify.io/posts/417604
//
// Slack permalinks that you Cmd+click in the apps in TERMINALS open in the Slack app.
// All other links open in Chrome.

// Slack desktop is signed in to Shopify's Enterprise Grid org. The org ID opens
// channels in all of the org's workspaces (Build, Support, Community).
const SLACK_ORG_ID = "E017D49VC3F";

const SLACK_HOSTS = [
  "shopify.enterprise.slack.com", // org
  "shopify.slack.com", // Build
  "shopify-support.slack.com", // Support
  "shopify-comm.slack.com", // Community
];

// Bundle IDs of apps where Slack links go to the Slack app.
// Find an ID with: osascript -e 'id of app "Ghostty"'
const TERMINALS = [
  "com.superlogical.rex", // Rex Beta
  "com.mitchellh.ghostty", // Ghostty
  "md.obsidian", // Obsidian
];

// "/archives/C08J7AHA3TQ/p1793629917355239" -> channel, ts seconds, ts micros
const PERMALINK_PATH = /^\/archives\/([A-Z0-9]+)(?:\/p(\d+)(\d{6}))?\/?$/;

export default {
  defaultBrowser: "Google Chrome",
  rewrite: [
    {
      match: (url, { opener }) =>
        SLACK_HOSTS.includes(url.hostname) &&
        PERMALINK_PATH.test(url.pathname) &&
        // Rex opens links from a short-lived child process, so Finicky sees no opener.
        (!opener?.bundleId || TERMINALS.includes(opener.bundleId)),
      url: (url) => {
        const [, channel, seconds, micros] = url.pathname.match(PERMALINK_PATH);
        let deepLink = `slack://channel?team=${SLACK_ORG_ID}&id=${channel}`;
        if (seconds) deepLink += `&message=${seconds}.${micros}`;
        const threadTs = url.search.match(/[?&]thread_ts=(\d+\.\d+)/);
        if (threadTs) deepLink += `&thread_ts=${threadTs[1]}`;
        return deepLink;
      },
    },
  ],
  handlers: [
    {
      match: (url) => url.protocol === "slack:",
      browser: {
        name: "com.tinyspeck.slackmacgap",
        appType: "bundleId",
        openInBackground: false,
      },
    },
  ],
};
