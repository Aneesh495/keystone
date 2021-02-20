<cfscript>
// Main request dispatcher for Keystone Gateway

// Resolve target route
requestUri = cgi.path_info ?: "";
if (len(trim(requestUri)) == 0) {
    requestUri = cgi.script_name ?: "/";
}

// Clean and normalize uri
normalizedUri = reReplace(requestUri, "^/index\.cfm", "");
if (len(trim(normalizedUri)) == 0) {
    normalizedUri = "/";
}

// Dispatch to router
router = application.kernel.getHttpRouter();
response = router.dispatch(
    method = cgi.request_method,
    path = normalizedUri,
    headers = getHttpRequestData().headers,
    body = toString(getHttpRequestData().content)
);

// Emit response
cfheader(statusCode = response.statusCode, statusText = response.statusText);
for (headerName in response.headers) {
    cfheader(name = headerName, value = response.headers[headerName]);
}
cfcontent(type = response.contentType, reset = true);
writeOutput(response.body);
</cfscript>
