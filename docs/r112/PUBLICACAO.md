# Publicação GitHub — R112

Atualização do projeto Godot público anteriormente na R78 para a base jogável R112 de 20 de novembro de 2026. Foram copiados código, modelos, texturas, áudio e dados do projeto atual, incluindo o mapa, combate, população fixa, nove personagens, menu, diálogo e estoques físicos.

## Verificação desta cópia

- Godot 4.4.1 Standard, Windows, renderizador Compatibility.
- 32 testes de integridade e atomicidade do abastecimento passaram nesta cópia.
- 11.368 referências externas dos modelos glTF conferidas, sem arquivos faltando.
- 13 verificações de abertura e persistência passaram no renderer real: inventário completo, fontes físicas, nove atores, rede social direcionada, 480 zumbis, menu, HUD R01, diálogo D02, câmera no ombro e salvar/carregar.
- [Resultado detalhado](publication_checks.json) e [captura real](capturas/09_copia_publicada.jpg).
- O [manifesto](runtime_manifest.json) registra os IDs Git dos arquivos publicados, com normalização de texto do Git.

A abertura utilizou o cache de importação da bancada local previamente validada. A primeira importação fria completa desta cópia não foi concluída nesta conferência. O cache não é versionado; no computador de quem baixar, o editor gera `.godot/` a partir dos recursos incluídos. Os resultados de regressão em `QA_RESULTADOS.json` pertencem à entrega de origem R112 e não representam uma repetição integral de todas as suítes na publicação.

## Adaptação para distribuição

O `project.godot` mantém a cena inicial e os controles atuais e altera somente o nome exibido e o diretório de dados público. Esse diretório continua `Entre_os_Andarilhos_Demo_R78` para permitir a leitura de perfis públicos anteriores compatíveis. O perfil atual é `user://demo_population_r98.json`. O teste de publicação gravou somente em `qa/publication/`.

Saves pessoais, anexos dos chats, logs, capturas de laboratório e caches não são enviados. As imagens de avaliação foram selecionadas explicitamente para a documentação. Os dados em `personagem/fixtures*` são fixtures autorais de testes, não perfis pessoais.

## Executar a conferência de abertura

Após importar o projeto, execute o binário Standard do Godot com:

```text
godot --path . --script res://tests/publication_smoke.gd -- --publication-smoke
```

Esse teste usa o renderer e uma campanha isolada em `qa/publication/`; pode levar alguns minutos para montar o mapa. Ele não altera a campanha pessoal. Para jogar normalmente, abra `project.godot` e pressione F5.

O projeto continua em desenvolvimento: nove dos 21 personagens estão integrados, H01 ainda tem adaptação de compatibilidade e o balanceamento/desempenho e fechamento narrativo permanecem pendentes. Esta atualização não inclui executável exportado nem declara a demo concluída.
