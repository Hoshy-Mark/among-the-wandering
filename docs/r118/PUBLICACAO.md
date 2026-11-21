# Publicação da base R118 — 21/11/2026

Esta publicação reúne a integração local R117 do mapa revisado e as correções R118 de acessos e HUD. O código está disponível para trabalho paralelo; isso não equivale à homologação de todos os interiores.

## Conteúdo

- Mapa revisado com 40 casas, adaptadores de exploração, cadastro de 590 recipientes/superfícies e loot finito.
- Compatibilidade com a campanha anterior, preservando o arquivo original durante a migração.
- Correções R118 e seus testes, resultados e capturas em `docs/r118/`.
- Roadmap completo, matriz pendente e tarefa de auditoria/proposta visual para outro chat em `docs/revisao_interiores/`.

O projeto abre em `demo_inventory.tscn` no Godot 4.4.1 Standard. A identificação da revisão foi atualizada para R118. A pasta histórica e o diretório de dados R78 foram mantidos para compatibilidade.

## Validação e limites

O relatório `REVISAO_R118.md` descreve os testes específicos já executados. A publicação repete `tests/map118.gd -- --full118` em processo novo e modo headless, usando somente o perfil isolado `qa/map118/profile.json`. Os resultados dessa repetição ficam em `publicacao_testes.json`, `integration.json` e `walk.json`. As imagens existentes foram capturadas anteriormente no Godot com renderização; o teste headless não produz evidência visual nova.

A revisão completa dos 590 registros continua pendente. As janelas da demo ainda estão limitadas às sete da H01; o rack tem relato de HUD a investigar. O aviso preexistente da textura de profundidade do lago é conhecido. Não foi realizado benchmark de FPS nesta publicação.

Não são publicados perfis pessoais, saves, cache `.godot/`, pasta de QA local nem logs de desenvolvimento. Reimportações automáticas de texturas e metadados de capturas existentes na máquina ficam fora deste commit; mantêm-se as configurações de importação já versionadas. O código, os dados e os resultados de QA selecionados são a base publicada.

## Trabalho paralelo

O outro chat deve seguir [TAREFA_CHATGPT_WEB.md](../revisao_interiores/TAREFA_CHATGPT_WEB.md): auditar os dados e produzir especificações visuais e lacunas de teste. Alterações, quando houver escrita, ficam somente em arquivos novos sob `docs/revisao_interiores/web/`, em branch separada. As correções de runtime, a aplicação de materiais e a validação no jogo ficam no chat local. Nenhuma tarefa é considerada aprovada apenas por leitura dos arquivos.
