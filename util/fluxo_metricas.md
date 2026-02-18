# Fluxo de Métricas: Matomo ➔ Hydra ➔ api-tabular ➔ MongoDB ➔ udata

Este documento detalha como as métricas (visualizações e downloads) circulam no ecossistema da plataforma, identificando os componentes envolvidos e o caminho que os dados percorrem.

## 1. Componentes do Fluxo

O ecossistema utiliza cinco componentes principais para gerir métricas:

1.  **Matomo (Analytics):** O motor de rastreamento. Ele recebe "pings" do frontend sempre que alguém visita uma página ou clica num download.
2.  **Hydra (PostgreSQL @ 5434):** Embora o Hydra seja primariamente um validador de recursos, no nosso ambiente a base de dados que ele gere serve como o **repositório de armazenamento de métricas agregadas**.
3.  **api-tabular (Serviço de Métricas @ 8006):** Uma camada de API (Python + PostgREST) que expõe os dados do PostgreSQL de forma estruturada para o udata.
4.  **MongoDB:** A base de dados principal do udata, que armazena os metadados dos datasets e os **totais consolidados das métricas**.
5.  **udata update-metrics (Job):** O "sincronizador" que faz a ponte entre a API Tabular e o MongoDB.

---

## 2. O Flow (Caminho do Dado)

O fluxo é assíncrono e dividido em etapas para garantir que o site continue rápido:

### Passo 1: Captura (Matomo)

Quando um utilizador interage com o site, o evento é enviado para o Matomo.

- **Estado:** O dado existe apenas como um log bruto (visita individual) no Matomo.

### Passo 2: Agregação (Data Pipeline)

Um processo externo (geralmente via Airflow ou Cron) lê os milhões de logs do Matomo e calcula os totais mensais por ID.

- **Ação:** Ele faz `INSERT` ou `UPDATE` nas tabelas `datasets` e `resources` da base de dados **PostgreSQL (Porto 5434)**.
- **Estado:** Os totais consolidados agora existem na base de dados "Hydra".

### Passo 3: Exposição (api-tabular)

O serviço `api-tabular` monitoriza as tabelas no PostgreSQL e expõe-nas via HTTP.

- **URL Exemplo:** `http://localhost:8006/api/datasets/data/`
- **Estado:** O dado está pronto para ser consumido pelo udata.

### Passo 4: Sincronização (udata job)

O comando `./venv/bin/udata job run update-metrics` é executado.

1.  Ele consulta a `api-tabular`.
2.  Pega nos totais (ex: Dataset X tem 500 views).
3.  Atualiza o documento do Dataset X no **MongoDB**.

### Passo 5: Exibição (Frontend)

O udata lê o MongoDB e mostra os números nas páginas.

---

## 3. O Happy Path (Caminho Ideal)

Para que tudo funcione bem em tempo real:

1.  O utilizador clica ➔ Matomo regista.
2.  O **Pipeline de Agregação** corre com sucesso e popula o Postgres (Hydra).
3.  A **api-tabular** está UP e a responder no porto 8006.
4.  O job **update-metrics** corre e encontra dados na API.
5.  O cache do udata é limpo (`udata cache flush`) para refletir os novos números.

---

## 4. O que está a faltar / Diagnóstico

Se os dados estão no Matomo mas não aparecem no udata, a falha está normalmente em um destes dois pontos:

### A. A Falha na Agregação (Matomo ➔ Postgres)

Este é o erro mais comum. O Matomo tem os logs, mas ninguém os moveu para as tabelas de métricas no Postgres (porto 5434).

- **Como testar:** Faça um `SELECT COUNT(*)` na tabela `datasets` no porto 5434. Se estiver vazia ou com dados antigos, o pipeline de agregação está parado.

### B. O Job de Sincronização (Postgres ➔ MongoDB)

O dado chegou ao Postgres, mas o `udata update-metrics` não foi corrido ou não conseguiu falar com a `api-tabular`.

- **Como testar:** Tente aceder a `http://localhost:8006/api/datasets/data/` no seu browser. Se a API devolver `[]` (vazio) ou erro, o `update-metrics` não terá nada para importar.

## 5. Próximos Passos Sugeridos

1.  **Verificar o PostgreSQL:** Confirmar se as tabelas criadas pelo script `setup_metrics_tables.sql` têm dados.
2.  **Validar a API:** Correr o comando curl:
    ```bash
    curl -s "http://localhost:8006/api/datasets/data/"
    ```
3.  **Correr o Sincronizador:** Se o passo 2 falhar, correr o job manualmente no ecossistema udata:
    ```bash
    udata job run update-metrics
    ```
