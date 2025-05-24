import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import TrieMap "mo:base/TrieMap";
import Json "mo:json";
import BaseX "mo:base-x-encoder";
import { str; obj } "mo:json";

import IC "ic:aaaaa-aa";
import Web "web";
import Prim "mo:⛔";

actor class StripeDemo({
  api_host: Text;
  api_key: Text;
  idempotent_proxy: ?Text
}) {

  let authorization : Text = BaseX.toBase64(Text.encodeUtf8(api_key # ":").vals(), true);

  type Status = {
    #checking;
    #failed: Text;
    #completed: Json.Json;
  };

  let sessions = TrieMap.TrieMap<Text, Status>(Text.equal, Text.hash);

  var nonce = 0;

  //function to transform the response
  public query func transform({
    // context : Blob;
    response : IC.http_request_result;
  }) : async IC.http_request_result {
    {
      response with headers = []; // not intersted in the headers
    };
  };

  func call_stripe(endpoint: Text) : async Text {
    let headers = Buffer.Buffer<{ name: Text; value: Text }>(4);
    headers.add({ name = "content-type"; value = "application/json"; });
    headers.add({ name = "authorization"; value = "Basic " # authorization; });

    let host = switch (idempotent_proxy) {
      case (?proxy_host) {
        headers.add({ name = "x-forwarded-host"; value = api_host });
        headers.add({ name = "idempotency-key"; value = "key-" # Nat.toText(nonce); });
        nonce := nonce + 1;
        proxy_host
      };
      case null api_host;
    };
    let response_size : Nat64 = 8192; // 8K max response
    let http_request : IC.http_request_args = {
      url = "https://" # host # "/" # endpoint;
      headers = Buffer.toArray(headers);
      max_response_bytes = ?response_size;
      body = null; //optional for request
      method = #get;
      transform = ?{ function = transform; context = Blob.fromArray([]); };
    };
    let estimated_base_size : Nat64 = Nat64.fromNat(Text.size(authorization) + 300);
    let cycles_amount = Prim.costHttpRequest(estimated_base_size, response_size);
    let response = await (with cycles = cycles_amount) IC.http_request(http_request);
    switch (Text.decodeUtf8(response.body)) {
      case null { throw Error.reject("UTF-8 encoding error in reply") };
      case (?body) { return body };
    }
  };

  public func fetch_stripe_checkout_session(session_id: Text): async ?Status {
    try {
      let reply = await call_stripe("v1/checkout/sessions/" # session_id);
      switch (Json.parse(reply)) {
        case (#ok(json)) {
          switch (Json.get(json, "error.code")) {
            case (?(#string(reason))) {
              sessions.put(session_id, #failed(reason));
            };
            case _ {
              sessions.put(session_id, #completed(json));
            }
          }
        };
        case (#err(err)) {
          sessions.put(session_id, #failed(debug_show(err)));
        }
      }
    } catch (err) {
      sessions.put(session_id, #failed(Error.message(err)))
    };
    sessions.get(session_id)
  };

  // Return cached results if found; otherwise upgrade incoming http requests to update call.
  public shared query func http_request(request: Web.HttpRequest): async Web.HttpResponse {
    var body = Text.encodeUtf8("");
    var upgrade : ?Bool = null;
    var status_code : Nat16 = 404;
    if (Text.startsWith(request.url, #text "/checkout/")) {
       let parts = Text.split(request.url, #char '/');
       ignore parts.next(); // skip '/'
       ignore parts.next(); // slip 'checkout'
       switch (parts.next()) {
         case (?session_id) {
           status_code := 200;
           switch (sessions.get(session_id)) {
             case (?#checking) {
               body := Text.encodeUtf8(Json.stringify(obj([("status", str("checking"))]), null));
             };
             case (?#failed(reason)) {
               body := Text.encodeUtf8(Json.stringify(obj([
                  ("status", str("failed")),
                  ("value", str(reason))]), null));
             };
             case (? #completed(json)) {
               body := Text.encodeUtf8(Json.stringify(obj([
                  ("status", str("completed")),
                  ("value", json)]), null));
             };
             case null {
              upgrade := ?true;
             }
           };
         };
         case null {}
       }
    };
    { headers = []; body; upgrade; status_code; }
  };

  public func http_request_update(request: Web.HttpUpdateRequest): async Web.HttpResponse {
    var headers = [("content-type", "application/json")];
    var body = Text.encodeUtf8("");
    var status_code : Nat16 = 404;
    if (Text.startsWith(request.url, #text "/checkout/")) {
       let parts = Text.split(request.url, #char '/');
       ignore parts.next(); // skip '/'
       ignore parts.next(); // slip 'checkout'
       switch (parts.next()) {
         case (?session_id) {
           sessions.put(session_id, #checking);
           body := Text.encodeUtf8(Json.stringify(obj([("status", str("checking"))]), null));
           ignore fetch_stripe_checkout_session(session_id);
           status_code := 200;
         };
         case null {
           status_code := 400;
         }
       }
    };
    { upgrade = null; headers; body; status_code; }
  };
}
