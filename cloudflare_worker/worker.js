const DIRECT_ROUTES = new Map([
  ['/', '/index.html'],
  ['/privacy', '/privacy/index.html'],
  ['/terms', '/terms/index.html'],
  ['/delete-account', '/delete-account/index.html'],
  ['/support', '/support/index.html'],
]);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname === 'www.partwk.com') {
      url.hostname = 'partwk.com';
      return Response.redirect(url.toString(), 301);
    }
    const assetPath = DIRECT_ROUTES.get(url.pathname) || url.pathname;
    const assetUrl = new URL(request.url);
    assetUrl.pathname = assetPath;

    const response = await env.ASSETS.fetch(new Request(assetUrl, request));
    const headers = new Headers(response.headers);
    headers.set('X-Robots-Tag', 'noindex, nofollow, noarchive');
    return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
  },
};
