# Entre os Andarilhos — Demo técnica R112 no Godot

Versão de desenvolvimento de Arroio das Figueiras: exploração isométrica, inventário modular, combate com câmera no ombro, população persistente de zumbis e nove personagens com diálogos e progressão social. A demo final está prevista com **21 personagens**; os doze restantes aguardam autoria. Esta versão ainda não representa a demo concluída.

## Baixar e jogar

1. Use **Code → Download ZIP** no GitHub, ou clone este repositório, e extraia toda a pasta.
2. Abra **Godot 4.4.1 Standard**. A edição .NET não é necessária.
3. No gerenciador de projetos, escolha **Importar** e selecione o `project.godot` da raiz.
4. Aguarde a importação dos recursos, abra o projeto e pressione **F5**.

O projeto usa o renderizador Compatibility. A primeira importação e a montagem do mapa podem levar alguns minutos; aguarde a tela de carregamento. A validação atual foi feita no Windows. Outros sistemas e computadores ainda precisam de testes. Não há executável publicado nesta atualização.

## Controles padrão

| Comando | Ação |
|---|---|
| WASD / Shift | Mover / correr |
| C | Alternar furtividade |
| I / H | Inventário / corpo e saúde |
| P | Menu de habilidades, personagens, mapa e configurações |
| E | Interagir com móvel, porta ou personagem próximo |
| J | Escolher gaveta do móvel acessado |
| V / B | Abrir ou fechar janela próxima / atravessar janela aberta ou cercamento |
| Botão direito do mouse | Segurar para mirar com arma de fogo; câmera passa ao ombro |
| Botão esquerdo do mouse / R | Atirar enquanto mira / recarregar |
| Q ou F / Espaço | Ataque corpo a corpo / empurrar |
| ↑ ou 1 | Atalho de arma longa |
| ← ou 2 | Atalho de arma curta |
| → ou 3 | Atalho de arma branca |
| ↓ ou 4 | Categoria de arremessável, ainda indisponível |
| Alt | Consultar o seletor de armas |
| 1–9 ou ↑/↓ e Enter, durante diálogo | Escolher resposta |
| Esc | Cancelar ou fechar a interação, quando permitido |

Vincule os equipamentos aos atalhos pelo inventário antes de usá-los. Os números são contextuais durante os diálogos. A HUD mostra a arma ativa; o seletor em cruz aparece temporariamente ao consultar ou trocar.

## Primeiro percurso

O início atual continua na área de teste da H01. Procure a mochila e o moletom no guarda-roupa; armas e suprimentos ocupam **dez compartimentos de oito móveis**. Abra as gavetas individualmente. Água e comida estão na geladeira e na despensa. A colocação dos itens na mochila é manual, sem organização automática.

Os recursos são finitos: consumir, recarregar, reabrir um móvel ou carregar a partida não repõe o estoque. As novas posições são usadas em partidas novas; campanhas antigas conservam seus itens e fontes originais.

Explore portas, janelas e cercamentos, pratique combate ou evite os zumbis. Há **480 identidades fixas**: 90 confinadas, 90 nos arredores vegetados da cidade e 300 na floresta exterior. Não há reposição arbitrária por spawn. Os nove encontros humanos atuais têm descoberta de informações, requisitos de vínculo e informação, testes de dados e progresso persistente. Relações entre NPCs existem; rotinas diárias completas ainda não estão prontas.

## Salvar e carregar

Use os botões **Salvar** e **Carregar** da barra. A campanha atual usa `user://demo_population_r98.json`, com backup. Preferências ficam em `user://preferences107.json`.

O diretório de dados público da versão R78 foi mantido para permitir a leitura da campanha anterior: `Entre_os_Andarilhos_Demo_R78`. O nome da pasta de dados não indica a versão do código. O jogo tenta importar o perfil legado compatível quando ainda não existe campanha atual. Seus saves não são enviados ao GitHub.

Para localizar os dados, use **Projeto → Abrir pasta de dados do usuário** no editor. Faça uma cópia antes de removê-los para reiniciar. A morte permite retomar um save válido ou começar uma nova tentativa.

## Estado da entrega

Inclui inventário C05, HUD de armas R01, diálogos D02, menu revisado, quatro habilidades e seis dimensões sociais centrais, incluindo Romance e Ressentimento. A R112 corrige a montagem parcial do inventário e distribui os estoques em móveis físicos.

Ainda pendentes: integração completa do interior H01 com o controlador atual do mapa, novo início exterior seguro, balanceamento e percursos longos, desempenho em outras máquinas, os doze personagens em autoria e o fechamento narrativo da demo. Há um aviso conhecido sobre o carregamento da textura de profundidade do lago. Não se trata de uma build final homologada.

- [Relatório R112](docs/r112/REVISAO_R112.md)
- [Resultados dos testes de origem](docs/r112/QA_RESULTADOS.json)
- [Verificação da publicação](docs/r112/PUBLICACAO.md)
- [Escopo dos 21 personagens](docs/r112/ESCOPO_DEMO_21_R111.md)
- [GDD social e progressão](docs/r112/GDD_v2_2_SOCIAL_R109.md)
- [Capturas reais](docs/r112/capturas/)

Preserve `personagem/`, `player/`, `population97/`, `main/` e `staging/`. Os arquivos `.import` contêm configurações de importação; `.godot/` é cache local e não é versionada. Ao relatar um problema, informe a versão do Godot, sistema, GPU, passos e mensagens de erro relevantes.

O pacote não altera as licenças dos recursos de origem nem atribui uma licença nova ao projeto.
