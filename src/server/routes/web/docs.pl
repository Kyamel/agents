:- module(route_docs, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).

:- http_handler(root(docs), handler, [method(get)]).

handler(_Request) :-
    reply_html_page(
        [ title('API Docs - Scotland Yard'),
          meta([charset('UTF-8')]),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          link([rel(stylesheet),
                href('https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css')])
        ],
        [ div([id('swagger-ui')], []),
          script([src('https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js')], []),
          script([], "window.onload=function(){SwaggerUIBundle({url:'/assets/openapi.json',dom_id:'#swagger-ui'});};")
        ]
    ).
