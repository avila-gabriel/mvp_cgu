# Problema e Solução

## Fontes

Este arquivo resume o entendimento do projeto a partir dos documentos em
`../documents/`:

- `gta-7-guia-de-transparencia-ativa-final.pdf`
- `SNAI.pptx`

Se houver divergência, os documentos originais prevalecem.

## Situação Atual

A avaliação formal de Transparência Ativa acontece no `STA`, dentro do
`Fala.BR`.

O órgão informa no `STA` se publica cada item obrigatório e indica o link exato
da página onde a informação está publicada. A `CGU` verifica o item no `STA` e
atribui um resultado:

- `Cumpre`
- `Cumpre Parcialmente`
- `Não Cumpre`

Quando o órgão altera ou atualiza informações no `STA`, a `CGU` pode reavaliar
o item no fluxo oficial.

O `STA` é privado. Este sistema não acessa nem monitora o `STA`.

## Problema

Na prática, a equipe precisa descobrir por varredura manual quais páginas e
itens devem ser conferidos novamente.

O material de referência descreve estes pontos:

- muitos itens e órgãos sob monitoramento;
- conferência individual com alto custo de tempo e força de trabalho;
- ausência de alertas automáticos quando páginas institucionais mudam;
- reavaliações puxadas por periodicidade ou tempo decorrido;
- risco de avaliações defasadas.

O ponto central é este: se uma página institucional muda, a equipe não recebe
automaticamente um aviso operacional. Sem aviso, a descoberta depende de abrir
os formulários e procurar por `Não verificado`.

## Solução

O sistema captura avaliações humanas feitas pela `CGU` e monitora as páginas
públicas relacionadas aos itens reprovados dessas avaliações.

Ao detectar uma mudança, o sistema primeiro filtra ruídos. Se a mudança não for
ruído, o sistema avalia se ela parece relevante para o item reprovado
correspondente.

Uma avaliação entra no inbox da equipe quando todos os seus itens reprovados
têm mudança considerada provavelmente relevante.

Essa entrada no inbox não altera o estado do item no `STA`. Ela também não
afirma que o item cumpre ou deixou de cumprir uma obrigação. Ela apenas indica
que há evidência suficiente para a equipe consultar o fluxo oficial.

## Fluxo

1. Durante uma avaliação humana, o sistema captura a avaliação.
2. O sistema identifica os itens reprovados nessa avaliação.
3. O sistema monitora as páginas públicas relacionadas a cada item reprovado.
4. Ao detectar mudança, o sistema registra a página, o horário e a evidência.
5. O sistema descarta mudanças classificadas como ruído.
6. Para mudanças que não são ruído, o sistema avalia a relevância em relação ao
   item reprovado.
7. Quando todos os itens reprovados da avaliação têm mudança provavelmente
   relevante, a avaliação aparece no inbox.
8. A equipe da `CGU` decide se deve consultar o `STA` ou fazer nova verificação.
9. A decisão formal continua sendo feita pela `CGU` no `STA`.

## Limites

O sistema pode:

- monitorar páginas públicas;
- detectar mudanças em conteúdo, links, documentos ou estrutura;
- filtrar ruídos;
- avaliar relevância provável da mudança em relação ao item reprovado;
- registrar evidências;
- enviar avaliações para o inbox quando todos os itens reprovados tiverem
  mudança provavelmente relevante.

O sistema não pode:

- acessar o `STA`;
- saber formalmente que um item voltou para `Não verificado`;
- substituir a avaliação da `CGU`;
- decidir `Cumpre`, `Cumpre Parcialmente` ou `Não Cumpre`;
- ler ou atualizar o `Painel LAI`.
