# Laboratório — Gestão de Pedidos com Microsserviços

Protótipo funcional de um sistema distribuído de **Gestão de Pedidos**, criado para a disciplina **ECOS02A — Sistemas Distribuídos (UNIFEI, 2026.2)**. Demonstra, em pequena escala, os conceitos estudados na pesquisa de [Teoria](../Teoria/Pesquisa_Completa_Microsservicos.md): serviços autônomos, API Gateway, comunicação entre serviços via HTTP, falhas parciais e rastreabilidade.

**Stack:** Node.js + TypeScript + Express 5 (backend) · React 19 + TypeScript + Vite + Tailwind CSS v4 (frontend)

**Repositórios no GitHub:**

| Repositório | Conteúdo |
|---|---|
| [MicroService-SistemasDistribuidos](https://github.com/Guismpaio2/MicroService-SistemasDistribuidos) | Este: visão geral, `docker-compose.yml` e scripts de inicialização |
| [backend-sistemas-distribuidos](https://github.com/Guismpaio2/backend-sistemas-distribuidos) | Os três microsserviços (gateway, produtos, pedidos) |
| [frontend-sistemas-distribuidos](https://github.com/Guismpaio2/frontend-sistemas-distribuidos) | Aplicação React |

---

## 1. Arquitetura

```
  ┌────────────┐      ┌──────────────────────┐   /api/produtos   ┌──────────────────┐
  │  Frontend  │ ───► │     API Gateway      │ ────────────────► │ produtos-service │
  │ React:5173 │      │        :3000         │                   │      :3001       │
  └────────────┘      │ CORS · x-request-id  │                   └────────▲─────────┘
                      │ roteamento · /health │                            │
                      └──────────┬───────────┘                            │ HTTP (axios)
                                 │ /api/pedidos                           │  GET  /produtos/:id
                                 ▼                                        │  POST /produtos/:id/estoque/baixa
                      ┌──────────────────────┐                            │
                      │   pedidos-service    │ ───────────────────────────┘
                      │        :3002         │
                      └──────────────────────┘
```

| Componente | Porta | Responsabilidade | "Banco" |
|---|---|---|---|
| `frontend` | 5173 | Interface React. **Só conhece o gateway.** | — |
| `backend/api-gateway` | 3000 | Porta de entrada: roteia `/api/*`, configura CORS, gera `x-request-id`, health agregado | — |
| `backend/produtos-service` | 3001 | Catálogo e **estoque** | Array em memória |
| `backend/pedidos-service` | 3002 | Pedidos. **Chama o produtos-service pela rede** | Array em memória |

### Fluxo de uma compra (`POST /api/pedidos`)

1. O React envia `{ productId, quantidade }` ao **gateway**.
2. O gateway reescreve `/api/pedidos` → `/pedidos` e encaminha ao **pedidos-service**, anexando `x-request-id`.
3. O pedidos-service faz um **`GET /produtos/:id`** real ao produtos-service (o produto existe? qual o preço? há estoque?).
4. Faz **`POST /produtos/:id/estoque/baixa`** para reservar as unidades.
5. Grava o pedido (com cópia do nome e do preço do momento da compra). Se essa gravação falhasse, executaria a **compensação** (`/estoque/devolucao`), uma saga orquestrada mínima.
6. Responde `201` com o pedido; o React recarrega produtos e pedidos.

Se o produtos-service estiver fora do ar, o pedidos-service responde **`503`** com mensagem clara (timeout de 3 s), em vez de travar.

---

## 2. Estrutura de pastas

```
Laboratorio/
├── readme.md                  ← este arquivo
├── docker-compose.yml         ← sobe tudo em contêineres (opcional)
├── iniciar.sh / iniciar.ps1   ← sobe tudo localmente com um comando
├── backend/                   ← repositório git: microsserviços
│   ├── api-gateway/           (Node/Express, porta 3000)
│   ├── produtos-service/      (Node/Express, porta 3001)
│   ├── pedidos-service/       (Node/Express, porta 3002)
│   └── scripts/               (dev.mjs: sobe os 3 serviços; smoke-test.sh)
└── frontend/                  ← repositório git: React + Vite
```

Cada serviço tem seu próprio `package.json`, `tsconfig.json` e `Dockerfile` e **não importa código de nenhum outro**. É a "implantação independente" da teoria. (O `requestLogger` está duplicado de propósito.)

---

## 3. Pré-requisitos

- **Node.js 22.15 ou superior** (`node -v`) e npm. *(O gateway usa `http-proxy-middleware` v4, que exige essa versão.)*
- Opcional: **Docker** com Compose v2, para a opção C.

---

## 4. Como executar

Escolha pelo que você quer fazer:

| Quero… | Comando | Terminais |
|---|---|---|
| **Tudo de uma vez** (backend + frontend) | `./iniciar.sh` (Windows: `.\iniciar.ps1`) | 1 |
| **Backend junto, frontend separado** | `cd backend && npm run dev` **e** `cd frontend && npm run dev` | 2 |
| **Cada serviço isolado** (para a apresentação) | um `npm run dev` por pasta (Opção C) | 4 |
| **Tudo em contêineres** | `docker compose up --build` | 1 |
| Só o backend (testar com `curl`) | `cd backend && npm run dev` | 1 |
| Só o frontend (backend já rodando) | `cd frontend && npm run dev` | 1 |

> **Não é obrigatório usar 4 terminais.** O `npm run dev` do backend já sobe os 3 serviços no mesmo terminal, com um log único e colorido (veja [Entendendo os logs](#entendendo-os-logs)). Use 4 terminais só se quiser ver cada serviço separado.

### Primeira vez: instalar as dependências

O `iniciar.sh` faz isso sozinho. Manualmente:

```bash
cd backend  && npm install && npm run install:all   # raiz + 3 serviços
cd ../frontend && npm install
```

### Opção A — Um comando (recomendado)

```bash
# macOS / Linux
./iniciar.sh
```

```powershell
# Windows (PowerShell)
.\iniciar.ps1
```

Instala o que faltar, verifica se as portas estão livres, sobe o backend e o frontend e encerra tudo com Ctrl+C. Depois abra **http://localhost:5173**.

### Opção B — Backend junto, frontend separado (2 terminais)

```bash
# terminal 1: os 3 microsserviços, no mesmo terminal
cd backend
npm run dev
```

```bash
# terminal 2: a interface React
cd frontend
npm run dev
```

Abra **http://localhost:5173**. Ctrl+C no terminal 1 encerra os três serviços de uma vez.

### Opção C — Cada processo em seu terminal (4 terminais)

Melhor para entender e para a apresentação: dá para ver o log de cada serviço isolado e derrubar um deles.

| Terminal | Comandos | Resultado |
|---|---|---|
| 1 | `cd backend/produtos-service && npm run dev` | `produtos  ▶ rodando em http://localhost:3001` |
| 2 | `cd backend/pedidos-service && npm run dev` | `pedidos   ▶ rodando em http://localhost:3002` |
| 3 | `cd backend/api-gateway && npm run dev` | `gateway   ▶ rodando em http://localhost:3000` |
| 4 | `cd frontend && npm run dev` | `Local: http://localhost:5173/` |

Instale antes as dependências de cada pasta (`npm install` dentro de cada uma).

### Opção D — Docker Compose

```bash
docker compose up --build
```

Sobe os 3 serviços + frontend (servido por nginx). Os serviços internos **não ficam expostos** ao seu computador; só o gateway (`:3000`) e o frontend (`:5173`). Encerrar: `docker compose down`.

### Scripts disponíveis

| Comando | Onde | O que faz |
|---|---|---|
| `npm run dev` | backend, cada serviço, frontend | Desenvolvimento com recarga ao salvar |
| `npm run build` | backend, cada serviço, frontend | Compila para `dist/` |
| `npm start` | backend, cada serviço | Executa a versão compilada (rode `build` antes) |
| `npm run typecheck` | backend, cada serviço | Verifica tipos sem gerar arquivos |
| `npm run smoke` | backend | Teste do fluxo completo (com os serviços rodando) |

### Entendendo os logs

Os três serviços escrevem no **mesmo formato**, em colunas, para você acompanhar uma compra pelo terminal:

```
HORA      SERVIÇO   ID      MENSAGEM
16:27:43  produtos  ec70b7  GET    /produtos/2                 200     0ms
16:27:43  pedidos   ec70b7    ↳ chama produtos-service: GET /produtos/2 → 200 (9ms)
16:27:43  produtos  ec70b7  ✔ estoque do produto #2: 40 → 38
16:27:43  produtos  ec70b7  POST   /produtos/2/estoque/baixa   200     1ms
16:27:43  pedidos   ec70b7  ✔ pedido #1 criado: 2× Mouse Sem Fio Ergonômico (R$ 259,80)
16:27:43  pedidos   ec70b7  POST   /pedidos                    201    20ms
16:27:43  gateway   ec70b7  POST   /api/pedidos               → pedidos   201    29ms
```

Como ler:

- **ID (6 caracteres):** é o identificador da requisição (`x-request-id`), gerado pelo gateway. **Todas as linhas com o mesmo id pertencem à mesma compra**, em qualquer serviço. Para isolar uma compra, procure o id (Cmd/Ctrl+F no terminal, ou `| grep ec70b7`). O gateway também devolve o id no cabeçalho de resposta: `curl -i localhost:3000/api/produtos | grep -i x-request-id`.
- **Ordem das linhas:** cada requisição é registrada **quando termina**. Por isso a linha mais interna (produtos) aparece primeiro e a mais externa (gateway) por último, como a pilha de chamadas se desfazendo.
- **`↳ chama ...`:** chamada que um serviço faz a outro (a comunicação entre serviços), com status e tempo.
- **`✔` ação concluída · `⚠` aviso (ex.: serviço fora do ar, compensação) · `✖` erro.**
- **Cores:** o nome do serviço tem cor própria; o status é verde (2xx), ciano (3xx), amarelo (4xx) ou vermelho (5xx); tempos acima de 500 ms ficam em amarelo.
- **`/health` não aparece:** o frontend e o gateway o consultam a cada poucos segundos e só poluiriam o log. Para vê-lo: `LOG_HEALTH=1 npm run dev`. Para desligar as cores: `NO_COLOR=1`.

## 5. Testando a API

Com os serviços rodando, tudo passa pelo gateway (`:3000`):

```bash
curl localhost:3000/api/produtos
curl localhost:3000/api/produtos/2
curl -X POST localhost:3000/api/pedidos -H 'content-type: application/json' \
     -d '{"productId": 2, "quantidade": 3}'
curl localhost:3000/api/pedidos
curl localhost:3000/health          # saúde do gateway e das dependências
```

Teste automatizado do fluxo completo (roteamento, 404/409/400, CORS):

```bash
cd backend && npm run smoke        # ou: ./scripts/smoke-test.sh http://localhost:3000
```

### Endpoints

| Via gateway | Serviço | Descrição | Respostas |
|---|---|---|---|
| `GET /api/produtos` | produtos | Lista produtos | 200 |
| `GET /api/produtos/:id` | produtos | Um produto | 200 · 400 · 404 |
| `POST /api/pedidos` | pedidos | Cria pedido `{ productId, quantidade }` | 201 · 400 · 404 · 409 · 503 |
| `GET /api/pedidos` | pedidos | Lista pedidos (mais recentes primeiro) | 200 |
| `GET /api/pedidos/:id` | pedidos | Um pedido | 200 · 404 |
| `GET /health` | gateway | Saúde agregada | 200 · 503 (degradado) |

Rotas internas (apenas entre serviços): `POST /produtos/:id/estoque/baixa` e `/estoque/devolucao`.

---

## 6. Roteiro de demonstração (para o seminário)

1. **Rastreabilidade.** Compre um produto e procure o mesmo **id de 6 caracteres** (`x-request-id`) nas linhas dos três serviços (veja [Entendendo os logs](#entendendo-os-logs)).
2. **Comunicação entre serviços.** O estoque do produto diminui: o pedidos-service pediu isso ao produtos-service pela rede.
3. **Falha parcial.** Derrube o `produtos-service` (Ctrl+C no terminal 1): em até 4 s o indicador do serviço fica vermelho; tentar comprar mostra o erro 503; a lista de pedidos continua funcionando. Suba o serviço de novo e tudo se recupera.
4. **Discussão.** Ao religar, o estoque volta ao valor inicial, porque os dados estão em memória. Pergunte à turma: *"o que o pedido existente garante agora? O que faltaria para isso nunca acontecer?"* (banco persistente, idempotência, eventos).

---

## 7. Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `EADDRINUSE: address already in use :::3000` | Outro programa usa a porta. Descubra com `lsof -nP -iTCP:3000 -sTCP:LISTEN` (macOS/Linux) ou `netstat -ano \| findstr :3000` (Windows), encerre-o ou use outras portas (ver abaixo). |
| Um serviço sobe, **mas as chamadas vão para outro programa** | O Node escuta em IPv6 (`*:3001`) e outro programa, como um contêiner Docker, pode escutar a mesma porta só em IPv4 (`127.0.0.1:3001`). As duas coexistem **sem erro**, e `localhost` pode cair em qualquer uma. Os scripts `iniciar.sh`/`iniciar.ps1` detectam isso e avisam; confira com `lsof -nP -iTCP:3001 -sTCP:LISTEN`. |
| Navegador mostra erro de **CORS** | O gateway só aceita as origens de `CORS_ORIGINS` (padrão `http://localhost:5173`). Se o Vite abrir em outra porta, ajuste a variável. |
| O frontend diz "Não foi possível falar com o API Gateway" | O gateway não está rodando, ou `VITE_API_URL` aponta para a porta errada. |
| Erros estranhos de módulo ao iniciar o gateway | Versão do Node abaixo de 22.15. Atualize. |
| `npm run dev` diz "Dependências ... não instaladas" | Rode `npm run install:all` dentro de `backend/`. |

### Usando outras portas (sem Docker)

Se alguma porta padrão estiver ocupada, mude-a **sem editar código**. No backend, com os 3 serviços em um terminal, use as variáveis `PORTA_*` (as URLs entre os serviços são ajustadas sozinhas):

```bash
# macOS / Linux
cd backend
PORTA_PRODUTOS=4001 PORTA_PEDIDOS=4002 PORTA_GATEWAY=4000 npm run dev

# frontend (outro terminal): aponta para o novo gateway
cd frontend
VITE_API_URL=http://localhost:4000/api npm run dev
```

```powershell
# Windows (PowerShell)
cd backend
$env:PORTA_PRODUTOS=4001; $env:PORTA_PEDIDOS=4002; $env:PORTA_GATEWAY=4000; npm run dev
cd ..\frontend
$env:VITE_API_URL="http://localhost:4000/api"; npm run dev
```

Se rodar cada serviço em seu próprio terminal (Opção C), use `PORT` no serviço e informe o endereço dos vizinhos:

```bash
cd backend/produtos-service && PORT=4001 npm run dev
cd backend/pedidos-service  && PORT=4002 PRODUTOS_SERVICE_URL=http://localhost:4001 npm run dev
cd backend/api-gateway      && PORT=4000 PRODUTOS_SERVICE_URL=http://localhost:4001 PEDIDOS_SERVICE_URL=http://localhost:4002 npm run dev
```

Com Docker: `GATEWAY_PORT=4000 FRONTEND_PORT=4173 docker compose up --build` (e `FRONTEND_ORIGIN=http://localhost:4173` ao rodar o smoke test).

---

## 8. Repositórios e convenção de commits

O projeto está organizado em **três repositórios Git independentes**:

| Repositório (GitHub) | Pasta local | Conteúdo |
|---|---|---|
| [MicroService-SistemasDistribuidos](https://github.com/Guismpaio2/MicroService-SistemasDistribuidos) | `Laboratorio/` | Orquestração: este readme, `docker-compose.yml`, scripts de inicialização (ignora `backend/` e `frontend/`) |
| [backend-sistemas-distribuidos](https://github.com/Guismpaio2/backend-sistemas-distribuidos) | `Laboratorio/backend/` | Os três microsserviços |
| [frontend-sistemas-distribuidos](https://github.com/Guismpaio2/frontend-sistemas-distribuidos) | `Laboratorio/frontend/` | A aplicação React |

Para montar o laboratório do zero em outra máquina:

```bash
git clone https://github.com/Guismpaio2/MicroService-SistemasDistribuidos.git Laboratorio
cd Laboratorio
git clone https://github.com/Guismpaio2/backend-sistemas-distribuidos.git backend
git clone https://github.com/Guismpaio2/frontend-sistemas-distribuidos.git frontend
./iniciar.sh
```

Os commits seguem **[Conventional Commits](https://www.conventionalcommits.org/pt-br/)**, com escopo por serviço. Ex.: `feat(pedidos-service): consulta produto via HTTP`, `fix(api-gateway): ...`, `docs: ...`, `build: ...`. Para ver o histórico: `git log --oneline --graph` dentro de cada pasta.

---

## 9. Limitações assumidas (bons pontos de discussão)

| O que falta | Em um sistema real |
|---|---|
| Persistência | Banco por serviço (PostgreSQL, MongoDB). Dados em memória somem ao reiniciar |
| Descoberta de serviços | URLs fixas em variáveis de ambiente → DNS do Kubernetes, Consul |
| Resiliência | Só há *timeout*; faltam *retries* com backoff e *circuit breaker* |
| Consistência | Saga síncrona mínima → eventos assíncronos (Kafka/RabbitMQ) + *outbox* |
| Idempotência | Reenviar o mesmo POST cria outro pedido → chave de idempotência |
| Segurança | Sem autenticação → OAuth2/JWT no gateway, mTLS entre serviços |
| Observabilidade | `x-request-id` nos logs → OpenTelemetry + Jaeger + Prometheus |
