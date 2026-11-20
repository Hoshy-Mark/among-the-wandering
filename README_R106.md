# R106 — base feminina e nove encontros

Abra `project.godot` na Godot 4.4.1 e execute a cena padrão. Renata tem encontro provisório junto à farmácia EST07, Pietra na fachada da igreja EST01 e Ana Julia na P01. Os seis encontros anteriores permanecem. Os nove personagens têm agora conversas de primeiro contato.

A cena feminina tem corpo, máscaras e roupas próprios, mantendo o rig de 58 ossos e os controles faciais. Coque e dois bobs usam blocos e cortes retos. Aparências e pontos são candidatos para avaliação. Os atores continuam estacionários, sem novas rotinas, lojas, missões ou combate humano.

E conversa; clique ou números/Enter respondem; Esc sai; P habilidades; I/H inventário/corpo. Armas continuam nas setas e 1–4 fora das interfaces. Os grafos R105 e o formato social de save não mudaram. Colocar os três atores não fabrica conversas em perfis antigos.

Testes:

```powershell
godot --path . --script res://personagem/qa_visual106.gd
godot --path . --script res://personagem/qa_mesh106.gd
godot --path . -- --qa-demo95 --characters106-test
godot --path . -- --qa-demo95 --characters106-test --characters106-reopen
```

A leitura de arrays de formas no teste de malha usa o renderer Compatibility, não o renderer dummy headless. Os testes de gameplay usam checkpoints em `qa/characters106/`; a fixture `personagem/fixtures106/legacy105.json` é um save de QA R105. O perfil normal segue `user://demo_population_r98.json`.

Scripts de geração e auditoria estão em `docs/personagens_r106/` na raiz do workspace. O delta depende do projeto R105 existente; não é um projeto standalone. O mapa atual, 480 zumbis e C-05 permanecem iguais. A H01 ainda usa o adaptador anterior.
