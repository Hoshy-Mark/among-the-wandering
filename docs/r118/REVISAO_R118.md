# R118 — acessos e HUD do mapa revisado

Correções locais aplicadas à integração R117, preservando o mapa atualizado. Esta revisão não homologa o mapa inteiro.

## Corrigido e verificado

- As três portas internas da H01 completam o giro. Uma correção pequena do pivô, com a folha fechada na mesma posição, evita o encontro com a parede na geometria ampliada. Não foram desligadas colisões de paredes.
- A caminhada deixa de ser cancelada quando a cápsula ainda toca o piso superior ao descer a soleira. Entrada e saída da H01 foram testadas com o controlador de caminhada, percorrendo mais de 1,8 m nos dois sentidos sem bloqueio.
- O recuo de abertura usa distância horizontal e leva em conta a escala local da porta, corrigindo a recusa nas entradas externas.
- Portas residenciais e cívicas podem usar o mesmo gesto/recuo e movimento controlado da H01. Os alvos são indexados por células para seleção e aviso por E. H02, H10 e H40 foram verificadas; H10 passou pelo caminho de entrada da tecla E.
- O móvel espera o gesto terminar em vez de cancelar quando a folha chega antes ao destino. Um guarda-roupa de duas folhas permite acesso pela folha livre, mantendo bloqueada a folha obstruída.
- Itens no chão são alvos de E e abrem o HUD aprovado. A coleta para a mochila foi verificada.
- O salvamento registra separadamente as folhas dos móveis. Arquivos R117 sem esse campo mantêm o comportamento anterior. Salvar e carregar o mapa revisado passaram; as portas externas não acrescentam chaves ao bloco legado de portas da H01.

## Evidências e limites

A execução nativa passou nas 13 verificações de integração registradas em `integration.json`. `walk.json` registra os dois sentidos da H01; `probe.json` registra os giros livres e o HUD com três itens do guarda-roupa. As capturas mostram o HUD real do Godot para o armário e para um item no chão criado pelo teste. Os perfis são isolados em `qa/map118/`; os perfis pessoais não foram usados.

Os testes novos foram feitos na revisão atual do mapa. Não se afirma que todas as portas, todos os recipientes ou todas as travessias tenham sido percorridos. As verificações antigas em mapa anterior não substituem esta auditoria.

## Por que o mapa inteiro ainda não estava liberado

O adaptador R117 registra 40 casas e 590 recipientes, mas o controlador de janelas da demo continua com sete entradas, todas da H01. Parte dos mecanismos e da exploração estava na bancada do mapa, sem ligação completa ao personagem da demo. Mostrar o mapa revisado não transfere automaticamente os controles, as travessias e a persistência dos acessos.

As portas agora compartilham o caminho de interação da demo, com verificações representativas acima. Ainda falta integrar as janelas das demais casas e fazer uma matriz de passagem e loot por imóvel. O mapa não deve ser apresentado como 100% explorável enquanto isso não passar.

## Reproduzir

No Godot 4.4.1 Standard, depois da importação:

```text
godot --path . --script res://tests/map118.gd -- --full118
```

O teste usa a integração atual, um perfil próprio e congela os zumbis para reproduzir os acessos. Os bloqueios físicos de móveis, paredes e outros atores permanecem no jogo normal. A pasta `qa/` não faz parte da publicação.
