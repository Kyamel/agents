(function () {
  "use strict";

  var tokenPattern =
    /(%[^\n]*|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\b\d+(?:\.\d+)?\b|\b[A-Z_][A-Za-z0-9_]*\b|\b[a-z][A-Za-z0-9_]*(?=\s*\()|:-|-->|[!;])/g;

  function tokenClass(token) {
    if (token[0] === "%") return "ph-comment";
    if (token[0] === "'" || token[0] === '"') return "ph-string";
    if (/^\d/.test(token)) return "ph-number";
    if (/^[A-Z_]/.test(token)) return "ph-variable";
    if (token === ":-" || token === "-->" ||
        token === "!" || token === ";") {
      return "ph-control";
    }
    return "ph-functor";
  }

  function highlight(element) {
    if (element.dataset.highlighted === "true") return;
    var source = element.textContent;
    var fragment = document.createDocumentFragment();
    var cursor = 0;
    var match;

    tokenPattern.lastIndex = 0;
    while ((match = tokenPattern.exec(source))) {
      if (match.index > cursor) {
        fragment.appendChild(
          document.createTextNode(source.slice(cursor, match.index))
        );
      }
      var token = document.createElement("span");
      token.className = tokenClass(match[0]);
      token.textContent = match[0];
      fragment.appendChild(token);
      cursor = tokenPattern.lastIndex;
    }
    if (cursor < source.length) {
      fragment.appendChild(document.createTextNode(source.slice(cursor)));
    }
    element.replaceChildren(fragment);
    element.dataset.highlighted = "true";
  }

  document.querySelectorAll(".js-prolog-highlight").forEach(highlight);
}());
