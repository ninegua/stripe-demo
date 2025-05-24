module {
  public type HeaderField = (Text, Text);
  public type HttpRequest = {
    url : Text;
    method : Text;
    body : Blob;
    headers : [HeaderField];
    certificate_version : ?Nat16;
  };
  public type HttpResponse = {
    body : Blob;
    headers : [HeaderField];
    upgrade : ?Bool;
    status_code : Nat16;
  };
  public type HttpUpdateRequest = {
    url : Text;
    method : Text;
    body : Blob;
    headers : [HeaderField];
  };
  public type Self = actor {
    http_request : shared query HttpRequest -> async HttpResponse;
    http_request_update : shared HttpUpdateRequest -> async HttpResponse;
  }
}
