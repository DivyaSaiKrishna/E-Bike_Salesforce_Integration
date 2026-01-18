/**
 * @description Encapsulates HTTP callout logic to ERP using a Named Credential.
 * Uses Database methods and standard Http classes. No state kept.
 * Named Credential usage: endpoint = 'callout:' + namedCredential + path
 * Adds X-Correlation-Id header when provided.
 * Never hardcodes base URLs per standards.
 * @author divya Sai krishna
 * @group Integration
 * @date 2026-01-18
 */
public with sharing class ErpHttpService {
    /**
     * @description Sends a JSON POST to the ERP endpoint using a Named Credential.
     * @param namedCredential The Named Credential name (e.g., 'ERP_NC')
     * @param path The relative path to append (e.g., '/orders')
     * @param body JSON string body
     * @param correlationId Optional correlation id header to add
     * @return HttpResponse returned by the callout
     * @throws CalloutException on transport errors
     */
    public static HttpResponse postJson(String namedCredential, String path, String body, String correlationId) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        String base = String.isBlank(namedCredential) ? '' : 'callout:' + namedCredential;
        String url = base + (String.isBlank(path) ? '' : path);
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        if (!String.isBlank(correlationId)) {
            req.setHeader('X-Correlation-Id', correlationId);
        }
        if (!String.isBlank(body)) {
            req.setBody(body);
        } else {
            req.setBody('{}');
        }
        return http.send(req);
    }
}
