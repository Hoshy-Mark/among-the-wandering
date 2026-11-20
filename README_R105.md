# R105 — Ricardo Alberto e nove roteiros preparados

Na cena padrão, Ricardo Alberto tem encontro provisório na fachada do mercado EST03, perto de `[124,0.3,140]`. Há seis personagens conversáveis no mapa. Os textos de Renata, Pietra e Ana Julia foram preparados/testados no domínio, mas elas ainda não estão na cena: aguardam a base feminina dedicada.

E conversa; clique ou números/Enter respondem; Esc sai. P abre as quatro habilidades fora da conversa; I/H mantêm inventário e corpo, setas/1–4 continuam armas.

O fazendeiro apresenta produção de alimentos, origem e uma posição sobre a expectativa de cura. O fato registra que ele fez essa declaração, não prova uma cura. Ouvir Jorge sobre o confinamento abre um assunto correspondente. Relações e Persuasão respeitam os registros anteriores, sem crédito por repetição. Perguntas pessoais não concedem seus segredos.

Os nove grafos são candidatos de escrita. Os seis atores continuam estacionários; não há comércio de comida, rotina ou missão nova. A aparência e o ponto do fazendeiro são provisórios. O mapa, malhas, animações, inventário C-05 e população fixa permanecem iguais; a H01 mantém o adaptador anterior.

```powershell
godot --headless --path . --script res://personagem/qa_social_model105.gd
godot --path . -- --qa-demo95 --characters105-test
godot --path . -- --qa-demo95 --characters105-test --characters105-reopen
```

O QA grava em `qa/characters105/`; a migração usa `personagem/fixtures105/legacy104.json`, um checkpoint de QA R104. O perfil normal permanece `user://demo_population_r98.json`. Relatório e galeria com oito capturas reais e transcrição dos roteiros ainda fora da cena: `docs/dialogo_r105/` na raiz do workspace.
