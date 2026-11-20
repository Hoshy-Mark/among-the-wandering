# HUD de armas R01

Abra este `project.godot` no **Godot 4.4.1** e execute `demo_inventory.tscn`.

Durante o jogo aparece somente o status da arma ativa no canto inferior direito. A cruz de atalhos surge por 1,5 segundo após uma tentativa de seleção e permanece aberta ao segurar Alt. O mundo continua em movimento.

| Categoria | Teclas padrão |
|---|---|
| Arma longa | ↑ ou 1 |
| Arma curta | ← ou 2 |
| Arma branca | → ou 3 |
| Arremessável, ainda indisponível | ↓ ou 4 |

Os vínculos continuam sendo configurados explicitamente no inventário. Selecionar a arma já ativa confirma a seleção; não guarda nem reequipe a arma. A munição exibida é carregada/capacidade, conforme o sistema existente. Armas brancas e mãos vazias não exibem contadores de balas.

Ações remapeáveis: `weapon_quick_up`, `weapon_quick_left`, `weapon_quick_right`, `weapon_quick_down`, `weapon_quick_consult`. I, H, R, mira, disparo e demais comandos conservam suas funções.

O inventário C-05, o formato do checkpoint e os sistemas de combate não foram substituídos. Os testes usam arquivos separados em `qa/hud_r01`, sem gravar no perfil normal do jogador.

Evidências, relatório, pacote de referência e rollback: `docs/hud_armas_r01` na raiz do workspace `Amoung the Wandering`. A homologação final depende da avaliação do diretor.
