# Laboratório — Gestão de Pedidos com Microsserviços

Protótipo funcional de um sistema distribuído de **Gestão de Pedidos**, criado para a disciplina **ECOS02A — Sistemas Distribuídos (UNIFEI, 2026.2)**. Demonstra, em pequena escala, os conceitos estudados na pesquisa de [Teoria](../Teoria/Pesquisa_Completa_Microsservicos.md): serviços autônomos, API Gateway, comunicação entre serviços via HTTP, falhas parciais e rastreabilidade.

**Stack:** Node.js + TypeScript + Express 5 (backend) · React 19 + TypeScript + Vite + Tailwind CSS v4 (frontend)

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
│   └── scripts/smoke-test.sh
└── frontend/                  ← repositório git: React + Vite
```

Cada serviço tem seu próprio `package.json`, `tsconfig.json` e `Dockerfile` e **não importa código de nenhum outro**. É a "implantação independente" da teoria. (O `requestLogger` está duplicado de propósito.)

---

## 3. Pré-requisitos

- **Node.js 22.15 ou superior** (`node -v`) e npm. *(O gateway usa `http-proxy-middleware` v4, que exige essa versão.)*
- Opcional: **Docker** com Compose v2, para a opção C.

---

## 4. Como executar

Escolha **uma** das três opções.

### Opção A — Um comando (recomendado)

```bash
# macOS / Linux
./iniciar.sh
```

```powershell
# Windows (PowerShell)
.\iniciar.ps1
```

Instala as dependências na primeira vez, verifica se as portas estão livres e sobe tudo. Depois abra **http://localhost:5173**.

### Opção B — Manual, passo a passo (melhor para entender e para a apresentação)

Use **4 terminais**, um por processo, para ver o log de cada serviço separadamente.

**1. Instalar as dependências** (uma única vez, uma pasta por vez):

```bash
cd backend/produtos-service && npm install
cd ../pedidos-service       && npm install
cd ../api-gateway           && npm install
cd ../../frontend           && npm install
```

**2. Iniciar cada processo** (um por terminal, a partir da pasta `Laboratorio/`):

| Terminal | Comandos | Resultado |
|---|---|---|
| 1 | `cd backend/produtos-service && npm run dev` | `produtos-service rodando em http://localhost:3001` |
| 2 | `cd backend/pedidos-service && npm run dev` | `pedidos-service rodando em http://localhost:3002` |
| 3 | `cd backend/api-gateway && npm run dev` | `api-gateway rodando em http://localhost:3000` |
| 4 | `cd frontend && npm run dev` | `Local: http://localhost:5173/` |

> Atalho para os 3 serviços do backend em **um** terminal: `cd backend && npm install && npm run install:all && npm run dev`.

**3. Abrir** http://localhost:5173.

Scripts disponíveis em cada serviço:

| Comando | O que faz |
|---|---|
| `npm run dev` | Inicia com recarga automática ao salvar (`tsx watch`) |
| `npm run build` | Compila TypeScript para `dist/` |
| `npm start` | Executa a versão compilada (`node dist/index.js`); rode `build` antes |
| `npm run typecheck` | Verifica os tipos sem gerar arquivos |

### Opção C — Docker Compose

```bash
docker compose up --build
```

Sobe os 3 serviços + frontend (servido por nginx). Os serviços internos **não ficam expostos** ao seu computador; só o gateway (`:3000`) e o frontend (`:5173`). Para encerrar: `docker compose down`.

---

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

1. **Rastreabilidade.** Compre um produto e procure o mesmo `x-request-id` nos logs dos três serviços.
2. **Comunicação entre serviços.** O estoque do produto diminui: o pedidos-service pediu isso ao produtos-service pela rede.
3. **Falha parcial.** Derrube o `produtos-service` (Ctrl+C no terminal 1): em até 4 s o indicador do serviço fica vermelho; tentar comprar mostra o erro 503; a lista de pedidos continua funcionando. Suba o serviço de novo e tudo se recupera.
4. **Discussão.** Ao religar, o estoque volta ao valor inicial, porque os dados estão em memória. Pergunte à turma: *"o que o pedido existente garante agora? O que faltaria para isso nunca acontecer?"* (banco persistente, idempotência, eventos).

---

## 7. Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `EADDRINUSE: address already in use :::3000` | Outro programa usa a porta. Descubra com `lsof -nP -iTCP:3000 -sTCP:LISTEN` (macOS/Linux) ou `netstat -ano \| findstr :3000` (Windows), encerre-o ou use outras portas (ver abaixo). |
| Navegador mostra erro de **CORS** | O gateway só aceita as origens de `CORS_ORIGINS` (padrão `http://localhost:5173`). Se o Vite abrir em outra porta, ajuste a variável. |
| O frontend diz "Não foi possível falar com o API Gateway" | O gateway não está rodando, ou `VITE_API_URL` aponta para a porta errada. |
| Erros estranhos de módulo ao iniciar o gateway | Versão do Node abaixo de 22.15. Atualize. |

### Usando outras portas (sem Docker)

Todas as portas e endereços são variáveis de ambiente. Exemplo com tudo deslocado:

```bash
# terminal 1
cd backend/produtos-service && PORT=4001 npm run dev
# terminal 2
cd backend/pedidos-service  && PORT=4002 PRODUTOS_SERVICE_URL=http://localhost:4001 npm run dev
# terminal 3
cd backend/api-gateway      && PORT=4000 PRODUTOS_SERVICE_URL=http://localhost:4001 PEDIDOS_SERVICE_URL=http://localhost:4002 npm run dev
# terminal 4
cd frontend                 && VITE_API_URL=http://localhost:4000/api npm run dev
```

Com Docker: `GATEWAY_PORT=4000 FRONTEND_PORT=4173 docker compose up --build`.

---

## 8. Repositórios e convenção de commits

O projeto está organizado em **três repositórios Git independentes**:

| Pasta | Conteúdo |
|---|---|
| `Laboratorio/` | Orquestração: este readme, `docker-compose.yml`, scripts de inicialização (ignora `backend/` e `frontend/`) |
| `Laboratorio/backend/` | Os três microsserviços |
| `Laboratorio/frontend/` | A aplicação React |

Os commits seguem **[Conventional Commits](https://www.conventionalcommits.org/pt-br/)**, com escopo por serviço. Ex.: `feat(pedidos-service): consulta produto via HTTP`, `fix(api-gateway): ...`, `docs: ...`, `build: ...`. Para ver o histórico: `git log --oneline` dentro de cada pasta.

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
