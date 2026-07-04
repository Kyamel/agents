:- begin_tests(slides).

:- use_module('../src/server/routes/web/slides').

test(extracts_safe_presentation_name) :-
    route_slides:extract_presentation_name('/slides/demo-2026', 'demo-2026').

test(rejects_nested_presentation_path, [fail]) :-
    route_slides:extract_presentation_name('/slides/demo/00', _).

test(rejects_path_traversal, [fail]) :-
    route_slides:extract_presentation_name('/slides/../config', _).

test(normalizes_numeric_page) :-
    route_slides:normalize_page('1', '01').

test(normalizes_zero_padded_page) :-
    route_slides:normalize_page('02', '02').

test(rejects_out_of_range_page, [fail]) :-
    route_slides:normalize_page('100', _).

test(lists_demo_presentation) :-
    route_slides:available_presentations(Presentations),
    member(presentation(demo, _, '00'), Presentations).

test(loads_demo_slide) :-
    route_slides:load_presentation(
        demo,
        '00',
        slide(Title, _, image(Image), _, _, _, _, _),
        navigation(none, 1, Total, some('/slides/demo?page=01'))
    ),
    Title == "Scotland Yard em Prolog",
    Total >= 5,
    sub_string(Image, 0, 8, _, "/assets/").

test(loads_image_with_right_text) :-
    route_slides:load_presentation(
        demo,
        '01',
        slide(_, _, Image, ImageAlt, none, _, RightText, _),
        _
    ),
    Image = image(_),
    ImageAlt = text(_),
    RightText = text(_),
    route_slides:slide_content_markup(
        Image, ImageAlt, none, none, RightText, _, wide
    ).

test(loads_two_images_side_by_side) :-
    route_slides:load_presentation(
        demo,
        '03',
        slide(
            _,
            _,
            image("/assets/slides/demo/imgs/example.png"),
            _,
            image("/assets/slides/demo/imgs/scotland-yard.jpg"),
            _,
            _,
            _
        ),
        _
    ),
    exists_file('assets/slides/demo/imgs/scotland-yard.jpg'),
    exists_file('assets/slides/demo/imgs/example.png').

test(loads_slide_without_image) :-
    route_slides:load_presentation(
        demo,
        '02',
        slide(_, _, none, _, none, _, _, _),
        _
    ).

test(only_title_is_required) :-
    route_slides:parse_slide(
        _{title: "Slide mínimo"},
        slide("Slide mínimo", none, none, none, none, none, none, none)
    ).

test(empty_and_null_fields_are_optional) :-
    route_slides:parse_slide(
        _{title: "Slide mínimo", subtitle: "", image: @(null)},
        slide("Slide mínimo", none, none, none, none, none, none, none)
    ).

test(second_image_works_without_first_image) :-
    route_slides:parse_slide(
        _{title: "Segunda", second_image: "/assets/segunda.png"},
        slide("Segunda", none, none, none, Image, none, none, none)
    ),
    route_slides:slide_content_markup(
        none, none, Image, none, none, figure(_, _), normal
    ).

test(rejects_slide_without_title, [fail]) :-
    route_slides:parse_slide(_{paragraph: "Sem título"}, _).

:- end_tests(slides).
