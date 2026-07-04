:- module(route_slides, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/json)).
:- use_module('../../views/page').
:- use_module('../../views/ui').

% Rota propositalmente ausente da navegacao principal. Cada apresentacao vive
% em assets/slides/<nome>/ e contem slides numerados de 00.json a 99.json.
:- http_handler(root(slides), index_handler, [method(get)]).
:- http_handler(root('slides/'), index_handler, [method(get)]).
:- http_handler('/slides/', handler, [method(get), prefix]).

index_handler(Request) :-
    available_presentations(Presentations),
    presentation_list(Presentations, ListHtml),
    ui:text_class(title, 'mb-3', TitleClass),
    ui:text_class(emphasis, 'text-surface-300 max-w-3xl mb-8', DescriptionClass),
    page:reply_page(Request, 'Apresentações', [
        h1([class(TitleClass)], 'Apresentações'),
        p([class(DescriptionClass)],
          'Escolha uma apresentação disponível neste servidor.'),
        ListHtml
    ]).

handler(Request) :-
    memberchk(path(Path), Request),
    extract_presentation_name(Path, Name),
    http_parameters(Request, [page(Page0, [default('00')])]),
    normalize_page(Page0, PageId),
    load_presentation(Name, PageId, Slide, Navigation),
    !,
    render_page(Name, Slide, Navigation).
handler(Request) :-
    http_404([], Request).

extract_presentation_name(Path, Name) :-
    atom_concat('/slides/', Name, Path),
    Name \== '',
    atom_length(Name, Length),
    Length =< 60,
    atom_codes(Name, Codes),
    maplist(safe_name_code, Codes).

safe_name_code(Code) :-
    code_type(Code, alnum),
    !.
safe_name_code(0'-).
safe_name_code(0'_).

available_presentations(Presentations) :-
    catch(directory_files('assets/slides', Entries), _, Entries = []),
    findall(
        Presentation,
        ( member(Name, Entries),
          Name \== '.',
          Name \== '..',
          atom_codes(Name, Codes),
          Codes \== [],
          maplist(safe_name_code, Codes),
          format(atom(Directory), 'assets/slides/~w', [Name]),
          exists_directory(Directory),
          presentation_summary(Name, Presentation)
        ),
        Unsorted
    ),
    sort(Unsorted, Presentations).

presentation_summary(Name, presentation(Name, Title, PageId)) :-
    presentation_slide_ids(Name, PageIds),
    member(PageId, PageIds),
    slide_file(Name, PageId, FilePath),
    read_slide(
        FilePath,
        slide(Title, _, _, _, _, _, _, _)
    ),
    !.

presentation_list([], Html) :-
    !,
    ui:padded_surface_class(normal, 'text-surface-400', Class),
    Html = p([class(Class)], 'Nenhuma apresentação disponível.').
presentation_list(Presentations,
                  ul([class('grid gap-3')], Items)) :-
    maplist(presentation_item, Presentations, Items).

presentation_item(
    presentation(Name, Title, PageId),
    li([class(CardClass)], [
        a([href(Href), class(LinkClass)], Title),
        p([class(NameClass)], Name)
    ])
) :-
    format(atom(Href), '/slides/~w?page=~w', [Name, PageId]),
    ui:padded_surface_class(normal, CardClass),
    ui:link_class('text-lg font-semibold', LinkClass),
    ui:text_class(meta, 'mt-2 font-mono text-surface-500', NameClass).

normalize_page(Page0, PageId) :-
    page_number(Page0, PageNumber),
    between(0, 99, PageNumber),
    format(atom(PageId), '~|~`0t~d~2+', [PageNumber]).

page_number(Page, Number) :-
    integer(Page),
    !,
    Number = Page.
page_number(Page, Number) :-
    atom(Page),
    atom_number(Page, Number),
    integer(Number),
    !.
page_number(Page, Number) :-
    string(Page),
    number_string(Number, Page),
    integer(Number),
    !.

load_presentation(Name, PageId, Slide, Navigation) :-
    presentation_slide_ids(Name, SlideIds),
    nth0(Position, SlideIds, PageId),
    slide_file(Name, PageId, FilePath),
    read_slide(FilePath, Slide),
    navigation(Name, SlideIds, Position, Navigation),
    !.

presentation_slide_ids(Name, SlideIds) :-
    findall(
        PageId,
        ( between(0, 99, PageNumber),
          format(atom(PageId), '~|~`0t~d~2+', [PageNumber]),
          slide_file(Name, PageId, FilePath),
          exists_file(FilePath)
        ),
        SlideIds
    ),
    SlideIds \== [].

slide_file(Name, PageId, FilePath) :-
    format(atom(FilePath), 'assets/slides/~w/~w.json', [Name, PageId]).

read_slide(FilePath, Slide) :-
    catch(
        setup_call_cleanup(
            open(FilePath, read, Stream, [encoding(utf8)]),
            json_read_dict(Stream, Json),
            close(Stream)
        ),
        _,
        fail
    ),
    parse_slide(Json, Slide).

parse_slide(
    Json,
    slide(
        Title,
        Subtitle,
        Image,
        ImageAlt,
        SecondImage,
        SecondImageAlt,
        RightText,
        Paragraph
    )
) :-
    get_dict(title, Json, Title),
    string(Title),
    Title \== "",
    optional_text(Json, subtitle, Subtitle),
    optional_image(Json, image, Image),
    optional_text(Json, image_alt, ImageAlt),
    optional_image(Json, second_image, SecondImage),
    optional_text(Json, second_image_alt, SecondImageAlt),
    optional_text(Json, right_text, RightText),
    optional_text(Json, paragraph, Paragraph).

optional_text(Json, Key, none) :-
    \+ get_dict(Key, Json, _),
    !.
optional_text(Json, Key, none) :-
    get_dict(Key, Json, Value),
    empty_optional_value(Value),
    !.
optional_text(Json, Key, text(Value)) :-
    get_dict(Key, Json, Value),
    string(Value).

optional_image(Json, Key, none) :-
    \+ get_dict(Key, Json, _),
    !.
optional_image(Json, Key, none) :-
    get_dict(Key, Json, Value),
    empty_optional_value(Value),
    !.
optional_image(Json, Key, image(Source)) :-
    get_dict(Key, Json, Source),
    valid_image_source(Source).

empty_optional_value("").
empty_optional_value(@(null)).

valid_image_source(Source) :-
    string(Source),
    sub_string(Source, 0, 1, _, "/"),
    \+ sub_string(Source, _, _, _, "..").

navigation(Name, SlideIds, Position,
           navigation(PreviousHref, Current, Total, NextHref)) :-
    length(SlideIds, Total),
    Current is Position + 1,
    adjacent_id(SlideIds, Position, -1, PreviousId),
    adjacent_id(SlideIds, Position, 1, NextId),
    slide_href(Name, PreviousId, PreviousHref),
    slide_href(Name, NextId, NextHref).

adjacent_id(_SlideIds, Position, -1, none) :-
    Position =:= 0,
    !.
adjacent_id(SlideIds, Position, -1, some(PageId)) :-
    PreviousPosition is Position - 1,
    nth0(PreviousPosition, SlideIds, PageId).
adjacent_id(SlideIds, Position, 1, none) :-
    length(SlideIds, Total),
    Position =:= Total - 1,
    !.
adjacent_id(SlideIds, Position, 1, some(PageId)) :-
    NextPosition is Position + 1,
    nth0(NextPosition, SlideIds, PageId).

slide_href(_Name, none, none).
slide_href(Name, some(PageId), some(Href)) :-
    format(atom(Href), '/slides/~w?page=~w', [Name, PageId]).

render_page(
    Name,
    slide(
        Title,
        Subtitle,
        Image,
        ImageAlt,
        SecondImage,
        SecondImageAlt,
        RightText,
        Paragraph
    ),
    navigation(PreviousHref, Current, Total, NextHref)
) :-
    format(atom(BrowserTitle), '~w — ~w', [Title, Name]),
    optional_subtitle_markup(Subtitle, SubtitleHtml),
    slide_content_markup(
        Image,
        ImageAlt,
        SecondImage,
        SecondImageAlt,
        RightText,
        ContentHtml,
        Width
    ),
    optional_paragraph_markup(Paragraph, ParagraphHtml),
    slide_class(Width, SlideClass),
    navigation_control(
        previous,
        PreviousHref,
        '← Anterior',
        'Ir para o slide anterior',
        PreviousControl
    ),
    navigation_control(
        next,
        NextHref,
        'Próximo →',
        'Ir para o próximo slide',
        NextControl
    ),
    format(atom(PageLabel), '~d / ~d', [Current, Total]),
    page:tailwind_config(TailwindConfig),
    keyboard_navigation_script(KeyboardNavigation),
    %format(atom(SlidesHref), '/slides/~w', [Name]),
    reply_html_page(
        [ title(BrowserTitle),
          meta([charset('UTF-8')]),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          meta([name(robots), content('noindex, nofollow')]),
          script([src('https://cdn.tailwindcss.com')], []),
          script([], TailwindConfig)
        ],
            [ \html_root_attribute(lang, 'pt-BR'),
            main([
                class('min-h-screen bg-surface-950 text-surface-200 flex flex-col \c
                        gap-3 sm:gap-5 p-3 sm:p-6 lg:p-8')
            ], [
                article([
                    class(SlideClass),
                    'aria-labelledby'('slide-title')
                ], [
                     a([
                        href('/slides'),
                        class('absolute top-2 left-2 sm:top-5 sm:left-5 \c
                            lg:top-8 lg:left-8 z-10 \c
                            overflow-hidden text-ellipsis whitespace-nowrap \c
                            text-ufop-400 text-sm font-bold uppercase \c
                            hover:underline transition-colors')
                    ], Name),
                  header([class('text-center pt-16 sm:pt-16 lg:pt-16')], [
                    h1([
                        id('slide-title'),
                        class('absolute top-8 left-8 right-8 \c
                            sm:top-5 sm:left-5 sm:right-5 \c
                            lg:top-12 lg:left-12 lg:right-12 \c
                            max-w-5xl mx-auto text-4xl sm:text-5xl lg:text-7xl \c
                            leading-none font-bold tracking-tight text-balance')
                    ], Title),
                    SubtitleHtml
                ]),
                  ContentHtml,
                  ParagraphHtml
              ]),
              nav([
                  class('w-full max-w-lg mx-auto grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] \c
                         items-center gap-2 sm:gap-3'),
                  'aria-label'('Navegação da apresentação')
              ], [
                  PreviousControl,
                  output([
                      class('min-w-16 sm:min-w-20 text-surface-300 font-bold \c
                             text-sm sm:text-base text-center tabular-nums'),
                      'aria-label'('Slide atual')
                  ], PageLabel),
                  NextControl
              ])
          ]),
          script([], KeyboardNavigation)
        ]
    ).

optional_subtitle_markup(none, '').
optional_subtitle_markup(text(Subtitle),
                         p([
                             class('max-w-3xl mx-auto mt-4 text-surface-300 \c
                                    text-lg lg:text-xl leading-relaxed text-balance')
                         ], Subtitle)).

optional_paragraph_markup(none, '').
optional_paragraph_markup(text(Paragraph),
                          p([
                              class('max-w-4xl mx-auto mt-6 lg:mt-8 text-surface-300 \c
                                     text-base lg:text-xl leading-relaxed text-center')
                          ], Paragraph)).

slide_class(
    normal,
    'flex-1 w-full relative max-w-6xl min-h-0 mx-auto flex flex-col justify-center \c
     rounded-2xl sm:rounded-3xl border border-surface-700 bg-surface-900 \c
     p-5 sm:p-10 lg:p-16 shadow-2xl'
).
slide_class(
    wide,
    'flex-1 w-full relative max-w-[96rem] min-h-0 mx-auto flex flex-col justify-center \c
     rounded-2xl sm:rounded-3xl border border-surface-700 bg-surface-900 \c
     p-5 sm:p-10 lg:p-16 shadow-2xl'
).

slide_content_markup(
    image(FirstSource),
    ImageAlt,
    image(SecondSource),
    SecondImageAlt,
    RightText,
    Html,
    wide
) :-
    !,
    image_figure(
        image(FirstSource),
        ImageAlt,
        'w-full h-full overflow-hidden rounded-2xl border border-surface-600 \c
         bg-surface-950 shadow-xl',
        'block w-full h-full max-h-[50vh] object-contain aspect-video',
        FirstFigure
    ),
    image_figure(
        image(SecondSource),
        SecondImageAlt,
        'w-full h-full overflow-hidden rounded-2xl border border-surface-600 \c
         bg-surface-950 shadow-xl',
        'block w-full h-full max-h-[50vh] object-contain aspect-video',
        SecondFigure
    ),
    two_image_content(FirstFigure, SecondFigure, RightText, Html).
slide_content_markup(
    image(Source),
    ImageAlt,
    none,
    _SecondImageAlt,
    text(RightText),
    div([
        class('w-full mt-6 lg:mt-8 grid grid-cols-1 \c
               md:grid-cols-[minmax(0,1.45fr)_minmax(18rem,.85fr)] \c
               items-center gap-6 lg:gap-16')
    ], [
        Figure,
        p([
            class('m-0 text-surface-300 text-lg lg:text-2xl leading-relaxed \c
                   text-center md:text-left')
        ], RightText)
    ]),
    wide
) :-
    !,
    image_figure(
        image(Source),
        ImageAlt,
        'w-full overflow-hidden rounded-2xl border border-surface-600 \c
         bg-surface-950 shadow-xl',
        'block w-full max-h-[50vh] object-contain aspect-video',
        Figure
    ).
slide_content_markup(
    none,
    _ImageAlt,
    image(Source),
    SecondImageAlt,
    text(RightText),
    div([
        class('w-full mt-6 lg:mt-8 grid grid-cols-1 \c
               md:grid-cols-[minmax(0,1.45fr)_minmax(18rem,.85fr)] \c
               items-center gap-6 lg:gap-16')
    ], [
        Figure,
        p([
            class('m-0 text-surface-300 text-lg lg:text-2xl leading-relaxed \c
                   text-center md:text-left')
        ], RightText)
    ]),
    wide
) :-
    !,
    image_figure(
        image(Source),
        SecondImageAlt,
        'w-full overflow-hidden rounded-2xl border border-surface-600 \c
         bg-surface-950 shadow-xl',
        'block w-full max-h-[50vh] object-contain aspect-video',
        Figure
    ).
slide_content_markup(
    image(Source),
    ImageAlt,
    none,
    _SecondImageAlt,
    none,
    Figure,
    normal
) :-
    !,
    image_figure(
        image(Source),
        ImageAlt,
        'w-full max-w-3xl mx-auto mt-6 lg:mt-8 overflow-hidden rounded-2xl \c
         border border-surface-600 bg-surface-950 shadow-xl',
        'block w-full max-h-[42vh] object-cover aspect-video',
        Figure
    ).
slide_content_markup(
    none,
    _ImageAlt,
    image(Source),
    SecondImageAlt,
    none,
    Figure,
    normal
) :-
    !,
    image_figure(
        image(Source),
        SecondImageAlt,
        'w-full max-w-3xl mx-auto mt-6 lg:mt-8 overflow-hidden rounded-2xl \c
         border border-surface-600 bg-surface-950 shadow-xl',
        'block w-full max-h-[42vh] object-cover aspect-video',
        Figure
    ).
slide_content_markup(
    none,
    _ImageAlt,
    none,
    _SecondImageAlt,
    text(RightText),
    p([
        class('max-w-4xl mx-auto mt-6 lg:mt-8 text-surface-300 text-lg \c
               lg:text-2xl leading-relaxed text-center')
    ], RightText),
    normal
) :-
    !.
slide_content_markup(
    none,
    _ImageAlt,
    none,
    _SecondImageAlt,
    none,
    '',
    normal
).

image_figure(image(Source), Alt, FigureClass, ImageClass,
             figure([class(FigureClass)], [
                 img([
                     src(Source),
                     alt(AltText),
                     class(ImageClass),
                     loading(eager),
                     decoding(async)
                 ])
             ])) :-
    optional_text_value(Alt, AltText).

optional_text_value(none, '').
optional_text_value(text(Value), Value).

two_image_content(
    FirstFigure,
    SecondFigure,
    none,
    div([
        class('w-full mt-6 lg:mt-8 grid grid-cols-1 md:grid-cols-2 \c
               items-stretch gap-4 lg:gap-8')
    ], [
        FirstFigure,
        SecondFigure
    ])
).
two_image_content(
    FirstFigure,
    SecondFigure,
    text(RightText),
    div([], [
        div([
            class('w-full mt-6 lg:mt-8 grid grid-cols-1 md:grid-cols-2 \c
                   items-stretch gap-4 lg:gap-8')
        ], [
            FirstFigure,
            SecondFigure
        ]),
        p([
            class('max-w-6xl mx-auto mt-6 lg:mt-8 text-surface-300 text-base \c
                   lg:text-xl leading-relaxed text-center')
        ], RightText)
    ])
).

navigation_control(Id, some(Href), Label, AriaLabel,
                   a([
                       id(Id),
                       href(Href),
                       class('min-h-12 flex items-center justify-center rounded-xl px-2 \c
                              sm:px-4 border border-surface-600 bg-surface-800 \c
                              text-surface-100 text-sm sm:text-base font-bold \c
                              hover:border-ufop-400 hover:bg-surface-700 transition \c
                              focus-visible:outline-none focus-visible:ring-2 \c
                              focus-visible:ring-ufop-400 focus-visible:ring-offset-2 \c
                              focus-visible:ring-offset-surface-950 \c
                              motion-reduce:transition-none'),
                       'aria-label'(AriaLabel)
                   ], Label)).
navigation_control(Id, none, Label, AriaLabel,
                   span([
                       id(Id),
                       class('min-h-12 flex items-center justify-center rounded-xl px-2 \c
                              sm:px-4 border border-surface-800 bg-surface-900 \c
                              text-surface-600 text-sm sm:text-base font-bold \c
                              cursor-not-allowed'),
                       'aria-label'(AriaLabel),
                       'aria-disabled'(true)
                   ], Label)).

keyboard_navigation_script(
    "(function(){\c
       'use strict';\c
       document.addEventListener('keydown',function(event){\c
         var target=null;\c
         if(event.key==='ArrowLeft'){target=document.getElementById('previous');}\c
         if(event.key==='ArrowRight'){target=document.getElementById('next');}\c
         if(target&&target.tagName==='A'){window.location.assign(target.href);}\c
       });\c
     })();"
).
