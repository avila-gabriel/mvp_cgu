- O HTML direto não serve: é uma SPA que só diz que requer JavaScript.
- A SPA chama um endpoint público: https://centralpaineis.cgu.gov.br/api/publico/visualizar/lai.
- Esse endpoint retorna configuração de embed do Power BI, incluindo embedUrl, reportId, groupId e um embedToken temporário.
- Com esse token, os endpoints internos do Power BI responderam 200 para metadados e schema.
- O schema contém tabelas de Transparência Ativa, incluindo:
  - 0300_fato_transparencia_ativa
  - 0301_dim_ta_assunto
  - 0302_dim_ta_item
  - 0310_dim_ta_avaliacao_ouvidoria_agregado
  - 0320_fato_ta_historico
- A tabela 0300_fato_transparencia_ativa expõe campos muito relevantes: TxtURLRespostaItemSIC, TxtResposta, DatVerificacao, DatResposta, status, item, assunto e órgão.

Também confirmei pela renderização que a aba “Transparência Ativa” mostra dados úteis como percentual de itens cumpridos, itens avaliados/total e ranking de órgãos.

Minha leitura: dá para usar como fonte auxiliar para seed/backfill, especialmente para descobrir órgãos, itens, status agregados e possivelmente URLs informadas no STA.
Mas é scraping de Power BI, com token temporário e API interna/não documentada. Pode quebrar sem aviso.
