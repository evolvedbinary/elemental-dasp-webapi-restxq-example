xquery version "3.1";

(:~
 : A very simple example XQuery Library Module implemented
 : in XQuery.
 :)
module namespace srv = "http://ns.evolvedbinary.com/dasp/service";

declare namespace rest = "http://exquery.org/ns/restxq";

declare
    %rest:GET
    %rest:path("/hello")
function srv:hello() {
  <hello>Welcome to DA 2025</hello>
};
