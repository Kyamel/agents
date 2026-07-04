:- module(route_about, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../views/page').
:- use_module('../../views/page_section').
:- use_module('../../views/ui').

:- http_handler(root(about), handler, [method(get)]).
:- http_handler(root('about/'), handler, [method(get)]).

handler(Request) :-
    hero(Hero),
    game_section(Game),
    characteristics_section(_Characteristics),
    agent_section(Agents),
    thief_section(Thief),
    detective_section(Detective),
    submission_section(Submission),
    page:reply_page(Request, 'Sobre o jogo e os agentes', [
        Hero,
        Game,
        %Characteristics,
        Agents,
        Thief,
        Detective,
        Submission
    ]).

hero(Html) :-
    ui:text_class(title, 'tracking-tight mb-4', TitleClass),
    ui:text_class(emphasis, 'text-surface-300 max-w-3xl', LeadClass),
    ui:text_class(meta, 'flex flex-wrap gap-3 mt-6', NavClass),
    ui:primary_button_class(compact, '', CtaClass),
    ui:secondary_button_class(SecondaryClass),
    Html = section([class('mb-10')], [
    h1([class(TitleClass)],
       'Programe um agente para Scotland Yard'),
    p([class(LeadClass)],
      'Crie um módulo Prolog que tome decisões como ladrão ou detetive. \c
       A plataforma valida o contrato do agente, executa a partida em turnos \c
       e registra cada ação para replay.'),
    nav([
        class(NavClass),
        'aria-label'('Navegação nesta página')
    ], [
        a([href('#como-funciona'),
           class(SecondaryClass)],
          'Como funciona'),
        a([href('#programar-agente'),
           class(SecondaryClass)],
          'Contrato dos agentes'),
        a([href('/agents/new'), class(CtaClass)],
          'Enviar meu agente')
    ])
]).

game_section(Html) :-
    section_title('Visão geral', 'Como a partida funciona', Title),
    step_card('1', 'Preparação',
              'O cenário fornece um grafo de cidades, itens, tesouros e suspeitos. \c
               Os agentes começam em cidades sorteadas.', S1),
    step_card('2', 'Decisões em turnos',
              'O ladrão age primeiro e o detetive responde. Ações válidas alteram \c
               o estado; ações ilegais consomem a oportunidade sem produzir efeito.', S2),
    step_card('3', 'Fim da partida',
              'O ladrão vence ao roubar o tesouro-alvo e sair da cidade do roubo. \c
               O detetive vence ao capturá-lo. Se os turnos terminarem, há empate.', S3),
    surface('p-6 sm:p-7', div([id('como-funciona'), class('scroll-mt-6')], [
        Title,
        div([class('grid md:grid-cols-3 gap-4')], [S1, S2, S3])
    ]), Html).

characteristics_section(Html) :-
    section_title('Características', 'O ambiente que seu agente enfrenta', Title),
    feature('Parcialmente observável',
            'Cada papel conhece seu próprio estado, mas não controla nem observa toda a estratégia adversária.',
            F1),
    feature('Sequencial e discreto',
            'Cada ação muda as decisões futuras; cidades, ações e turnos formam conjuntos finitos.',
            F2),
    feature('Multiagente adversarial',
            'Ladrão e detetive possuem objetivos opostos e agem sobre o mesmo mapa.',
            F3),
    feature('Regras determinísticas',
            'Uma ação válida tem efeito definido, embora a estratégia do oponente continue incerta.',
            F4),
    feature('Memória permitida',
            'Predicados dinâmicos podem guardar o mapa e decisões calculadas durante o preload.',
            F5),
    feature('Execução controlada',
            'Cada partida roda em subprocesso separado, com limite de tempo e validação estática do código.',
            F6),
    Html = section([class('my-8')], [
        Title,
        div([class('grid sm:grid-cols-2 lg:grid-cols-3 gap-x-3')],
            [F1, F2, F3, F4, F5, F6])
    ]).

agent_section(Html) :-
    section_title('Primeiros passos', 'O contrato de um agente', Title),
    contract_item('1', 'Comece por module/2',
                  'A primeira declaração deve nomear o módulo e exportar a \c
                   interface obrigatória do papel.', C1),
    contract_item('2', 'Carregue o cenário',
                  'O predicado de preload recebe mapa, suspeitos, itens e tesouros. \c
                   Use-o para preparar fatos e escolher sua estratégia inicial.', C2),
    contract_item('3', 'Escolha uma ação',
                  'A cada turno, action/3 recebe eventos e o estado atual. O terceiro \c
                   argumento deve ser unificado com uma ação aceita pela engine.', C3),
    contract_item('4', 'Tenha um fallback',
                  'Se nenhuma regra produzir uma ação, use nada. Isso evita que uma \c
                   falha lógica derrube sua estratégia inteira.', C4),
    data_shapes(Shapes),
    surface('p-6 sm:p-7', div([id('programar-agente'), class('scroll-mt-6')], [
        Title,
        div([class('grid sm:grid-cols-2 gap-4')], [C1, C2, C3, C4]),
        Shapes
    ]), Html).

data_shapes(Html) :-
    signature('Grafo', '[adj(CidadeA, CidadeB), ...]', S1),
    signature('Suspeitos', '[procurado(Id, aparencia(Atributos)), ...]', S2),
    signature('Itens', '[item(Nome, Cidade, Requisitos), ...]', S3),
    signature('Tesouros', '[tesouro(Nome, Cidade, Requisitos), ...]', S4),
    signature('Eventos', '[roubo(Item, Cidade, Pistas), ...]', S5),
    signature('Estado do ladrão',
              'thief(loc(Cidade), Id, Aparência, Alvo, Itens, Disfarces)', S6),
    signature('Estado do detetive',
              'detective(loc(Cidade), Mandato, Pistas)', S7),
    ui:text_class(normal, 'grid lg:grid-cols-2 gap-x-8 gap-y-3', ShapesClass),
    Html = div([class('mt-7 border-t border-surface-700 pt-6')], [
    h3([class('font-semibold mb-3')], 'Dados recebidos da engine'),
    div([class(ShapesClass)], [
        S1, S2, S3, S4, S5, S6, S7
    ])
]).

thief_section(Html) :-
    thief_example(Code),
    role_header(amber, 'Ladrão',
                'Colete os requisitos, roube o tesouro escolhido e deixe a cidade \c
                 onde o roubo aconteceu antes de ser capturado.', Header),
    action_chip('move(Origem, Destino)', A1),
    action_chip('roubar(ItemOuTesouro)', A2),
    action_chip('disfarce(Mudanças)', A3),
    action_chip('despir_disfarce', A4),
    action_chip('nada', A5),
    code_block(Code, CodeBlock),
    contract_signature('ladrao_preload/7',
        'ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, IdEscolhido, TesouroAlvo).',
        P1),
    contract_signature('ladrao_action/3',
        'ladrao_action(Eventos, EstadoDoLadrao, Acao).',
        P2),
    ui:text_class(normal, 'text-surface-400 mt-4', HintClass),
    surface('p-6 sm:p-7', section([id('agente-ladrao'), class('scroll-mt-6')], [
        Header,
        div([class('grid lg:grid-cols-2 gap-5 mt-5')], [P1, P2]),
        h3([class('font-semibold mt-6 mb-3')], 'Ações disponíveis'),
        div([class('flex flex-wrap gap-2')], [A1, A2, A3, A4, A5]),
        p([class(HintClass)],
          'Cada roubo revela pistas da aparência atual. O disfarce pode mudar essa \c
           informação; tentar sair de uma cidade fechada causa captura.'),
        h3([class('font-semibold mt-7 mb-3')], 'Estrutura mínima'),
        CodeBlock
    ]), Html).

detective_section(Html) :-
    detective_example(Code),
    role_header(sky, 'Detetive',
                'Use os eventos de roubo para deduzir a identidade, controlar o \c
                 mapa e capturar o ladrão com um mandato válido.', Header),
    action_chip('move(Origem, Destino)', A1),
    action_chip('pedir_mandato(Id, Pistas)', A2),
    action_chip('inspecionar', A3),
    action_chip('fechar(Cidade)', A4),
    action_chip('liberar(Cidade)', A5),
    action_chip('nada', A6),
    code_block(Code, CodeBlock),
    contract_signature('detetive_preload/5',
        'detetive_preload(Grafo, Suspeitos, Itens, Tesouros, pronto).',
        P1),
    contract_signature('detetive_action/3',
        'detetive_action(Eventos, EstadoDoDetetive, Acao).',
        P2),
    ui:text_class(normal, 'text-surface-400 mt-4', HintClass),
    surface('p-6 sm:p-7', section([id('agente-detetive'), class('scroll-mt-6')], [
        Header,
        div([class('grid lg:grid-cols-2 gap-5 mt-5')], [P1, P2]),
        h3([class('font-semibold mt-6 mb-3')], 'Ações disponíveis'),
        div([class('flex flex-wrap gap-2')], [A1, A2, A3, A4, A5, A6]),
        p([class(HintClass)],
          'O mandato deve usar pistas já conhecidas, identificar um suspeito \c
           compatível e reduzir o conjunto de suspeitos possíveis a no máximo dois. \c
           Inspecionar só captura quando o mandato e a cidade estão corretos.'),
        h3([class('font-semibold mt-7 mb-3')], 'Estrutura mínima'),
        CodeBlock
    ]), Html).

submission_section(Html) :-
    ui:link_class(LinkClass),
    ui:text_class(section, 'mb-2', TitleClass),
    ui:text_class(normal, 'space-y-2 text-surface-300 list-disc pl-5', ListClass),
    Html = section([class('my-8 rounded-xl border border-ufop-900 bg-ufop-950/40 p-6 sm:p-7')], [
        h2([class(TitleClass)], 'Antes de enviar'),
        ul([class(ListClass)], [
            li([], 'O nome do módulo deve ter entre 3 e 60 caracteres e não pode conter / ou \\.'),
            li([], 'O papel é detectado pelos predicados exportados em module/2.'),
            li([], 'Diretivas e operações perigosas, como initialization, use_module, consult, open, process_create e shell, são bloqueadas.'),
            li([], 'Código privado continua executável, mas não é exibido pela API pública.')
        ]),
        p([class('mt-5')], [
            a([href('/agents/new'), class(LinkClass)], 'Abrir a tela Enviar agente'),
            ' para colar o módulo completo no campo',
            strong([],' Código Prolog'),
            '.'
        ])
    ]).

section_title(Eyebrow, Title, Html) :-
    page_section:eyebrow_heading(Eyebrow, Title, Html).

step_card(Number, Title, Text, Html) :-
    ui:text_class(meta,
                  'inline-flex items-center justify-center w-7 h-7 rounded-full \c
                   bg-ufop-950 text-ufop-400 border border-ufop-900 font-bold mb-3',
                  NumberClass),
    ui:text_class(normal, 'text-surface-400', TextClass),
    Html = div([class('rounded-lg bg-surface-950/60 border border-surface-700 p-4')], [
    span([class(NumberClass)],
         Number),
    h3([class('font-semibold mb-1')], Title),
    p([class(TextClass)], Text)
]).

feature(Title, Text, Html) :-
    ui:text_class(normal, 'font-semibold mb-1', TitleClass),
    ui:text_class(normal, 'text-surface-400', TextClass),
    surface('p-4', div([], [
        h3([class(TitleClass)], Title),
        p([class(TextClass)], Text)
    ]), Html).

contract_item(Number, Title, Text, Html) :-
    ui:text_class(normal, 'font-semibold', TitleClass),
    ui:text_class(normal, 'text-surface-400 mt-1', TextClass),
    Html = div([class('flex gap-3')], [
    span([class('text-ufop-400 font-mono font-bold')], Number),
    div([], [
        h3([class(TitleClass)], Title),
        p([class(TextClass)], Text)
    ])
]).

signature(Label, Value, Html) :-
    ui:eyebrow_class(slate, LabelClass),
    Html = div([], [
    p([class(LabelClass)], Label),
    code([class('text-surface-300 break-all')], Value)
]).

role_header(Accent, Title, Description, Html) :-
    ui:eyebrow_class(Accent, AccentClass),
    ui:text_class(title, 'mt-1', TitleClass),
    Html = div([], [
    p([class(AccentClass)], 'Papel do agente'),
    h2([class(TitleClass)], Title),
    p([class('text-surface-400 mt-2 max-w-2xl leading-relaxed')], Description)
]).

contract_signature(Name, Signature, Html) :-
    ui:eyebrow_class(slate, NameBase),
    atomic_list_concat([NameBase, 'mb-2'], ' ', NameClass),
    ui:text_class(meta, 'text-surface-200 break-all', SignatureClass),
    Html = div([class('rounded-lg bg-surface-950/70 border border-surface-700 p-4')], [
    p([class(NameClass)], Name),
    code([class(SignatureClass)], Signature)
]).

action_chip(Text, Html) :-
    ui:text_class(meta,
                  'rounded-md bg-surface-800 border border-surface-600 \c
                   px-2.5 py-1.5 text-surface-300',
                  Class),
    Html = code([class(Class)], Text).

code_block(Code, Html) :-
    ui:text_class(meta,
                  'overflow-x-auto rounded-lg bg-surface-950 border \c
                   border-surface-700 p-4 text-surface-300',
                  Class),
    Html = pre([class(Class)], code([], Code)).

surface(Extra, Content, div([class(Class)], [Content])) :-
    atomic_list_concat(['my-8', Extra], ' ', FullExtra),
    ui:surface_class(FullExtra, Class).

thief_example(Code) :-
    code_lines([
        ":- module(meu_ladrao, [",
        "    ladrao_preload/7,",
        "    ladrao_action/3",
        "]).",
        "",
        ":- dynamic caminho/2.",
        ":- dynamic tesouro_conhecido/3.",
        "",
        "ladrao_preload(Grafo, [procurado(Id, _)|_], _Itens, Tesouros,",
        "               pronto, Id, Alvo) :-",
        "    retractall(caminho(_, _)),",
        "    retractall(tesouro_conhecido(_, _, _)),",
        "    forall(member(adj(A, B), Grafo),",
        "           (assertz(caminho(A, B)), assertz(caminho(B, A)))),",
        "    forall(member(tesouro(T, C, Rs), Tesouros),",
        "           assertz(tesouro_conhecido(T, C, Rs))),",
        "    Tesouros = [tesouro(Alvo, _, _)|_].",
        "",
        "ladrao_action(_, thief(loc(C), _, _, Alvo, Itens, _), roubar(Alvo)) :-",
        "    tesouro_conhecido(Alvo, C, Requisitos),",
        "    requisitos_ok(Requisitos, Itens), !.",
        "ladrao_action(_, thief(loc(C), _, _, _, _, _), move(C, Proxima)) :-",
        "    caminho(C, Proxima), !.",
        "ladrao_action(_, _, nada).",
        "",
        "requisitos_ok([], _).",
        "requisitos_ok([R|Rs], Itens) :-",
        "    memberchk(R, Itens), requisitos_ok(Rs, Itens)."
    ], Code).

detective_example(Code) :-
    code_lines([
        ":- module(meu_detetive, [",
        "    detetive_preload/5,",
        "    detetive_action/3",
        "]).",
        "",
        ":- dynamic caminho/2.",
        "",
        "detetive_preload(Grafo, _Suspeitos, _Itens, _Tesouros, pronto) :-",
        "    retractall(caminho(_, _)),",
        "    forall(member(adj(A, B), Grafo),",
        "           (assertz(caminho(A, B)), assertz(caminho(B, A)))).",
        "",
        "detetive_action(_, detective(_, Mandato, _), inspecionar) :-",
        "    Mandato \\= nenhum, !.",
        "detetive_action(_, detective(loc(C), _, _), move(C, Proxima)) :-",
        "    caminho(C, Proxima), !.",
        "detetive_action(_, _, nada)."
    ], Code).

code_lines(Lines, Code) :-
    atomic_list_concat(Lines, '\n', Code).
