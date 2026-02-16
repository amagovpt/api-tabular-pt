# Fluxo de Métricas e Sincronização de Dados

Este documento descreve o funcionamento do fluxo de métricas (views e downloads) no ecossistema do udata, baseado na análise técnica realizada no ambiente de desenvolvimento.

## 1. O Fluxo de Dados (Step-by-Step)

O fluxo de métricas segue uma cadeia de quatro camadas distintas para garantir performance e desacoplamento:

1.  **Rastreamento (Origem):**
    - Quando um utilizador visualiza um dataset ou faz download de um recurso, o frontend (ou um redirecionamento de URL) envia um evento para o **Matomo (Piwik)**. No seu caso, o servidor Matomo está no IP `10.55.37.39`.
    - Nesta fase, os dados são apenas logs brutos no banco de dados MySQL do Matomo.

2.  **Agregação (Pipeline de Dados):**
    - **Este é o elo crucial:** Deve existir um script ou processo (ex: Airflow ou cron job) que lê as visitas brutas do Matomo e calcula os totais por objeto e por mês.
    - Este processo escreve os totais agregados na base de dados **PostgreSQL (porto 5434)** nas tabelas `datasets`, `resources`, etc.
    - _Nota: Se este passo não correr, o udata nunca verá novas ações do site._

3.  **Exposição (Camada de API):**
    - O serviço **`api-tabular`** (via PostgREST no porto 8006) expõe os dados do PostgreSQL.
    - Ela serve como uma interface de leitura rápida para o udata.

4.  **Sincronização (MongoDB e Frontend):**
    - O comando **`udata job run update-metrics`** acorda e consulta a `api-tabular`.
    - Ele lê os totais (ex: "500 visitas") e salva-os no campo `metrics` do **MongoDB**.
    - O frontend do udata lê o MongoDB para exibir os números e gráficos na página do dataset.

## 2. Perguntas Frequentes (FAQ)

### O udata salva ações (cliques/views) diretamente no MongoDB?

Não. Para evitar sobrecarga, o MongoDB guarda apenas os **totais consolidados**. Cada clique individual é gerido pelo Matomo para não atrasar a resposta do site ao utilizador.

### O job `update-metrics` vai buscar dados ao Matomo?

Não. O `update-metrics` é apenas um sincronizador. Ele fala exclusivamente com a **`api-tabular`**. Ele assume que os dados já foram processados e inseridos no PostgreSQL por um processo anterior.

### Como confirmar se as métricas estão a ser geradas corretamente?

Se correr o `update-metrics` com o `cache flush` e os valores não mudarem, o problema está no **Passo 2 (Agregação)**. O udata só consegue sincronizar o que já existe no PostgreSQL. Pode testar inserindo dados manualmente no Postgres (porto 5434); se eles aparecerem no site após o job, a "ponte" Postgres -> Mongo está a funcionar bem.

## 3. Comandos Úteis

- **Sincronizar métricas para o site:**
  ```bash
  ./venv/bin/udata job run update-metrics
  ```
- **Limpar cache (para ver as alterações no frontend):**
  ```bash
  ./venv/bin/udata cache flush
  ```
- **Verificar o que a API de métricas está a devolver:**
  ```bash
  curl -s "http://localhost:8006/api/datasets_total/data/?dataset_id__exact=<ID_DO_DATASET>"
  ```
