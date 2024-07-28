import type WebSocketClient from "websocket-async";
import type { UUID } from "crypto";

export type Insert = {
  type: "insert";
  position: number;
  text: string;
  from: string;
};

export type Delete = {
  type: "delete";
  position: number;
  amount: number;
  from: string;
};

export type Change = Insert | Delete | undefined;

type StartMessage = "start";
type StartResponse = {
  type: "start";
  document: string;
  currentId: number;
};

type PushMessage = {
  type: "push";
  changes: Change[];
};
type PushResponse = "push";

type PullMessage = {
  type: "pull";
  lastPulled: number;
};
type PullResponse = {
  type: "pull";
  pulledChanges: Change[];
  currentId: number;
};

type Message = StartMessage | PullMessage | PushMessage;

type Response = StartResponse | PullResponse | PushResponse;

export class Messenger {
  websocket: WebSocketClient;
  clientId: UUID;
  lastPulled: number;

  // probably could have gotten away with using fetch requests for this instead of websocket
  #sendMessage = async (message: Message): Promise<Response> => {
    this.websocket.send(JSON.stringify(message));

    const response = await this.websocket.receive();

    return JSON.parse(response) as Response;
  };

  constructor(websocket: WebSocketClient) {
    this.websocket = websocket;
    this.clientId = self.crypto.randomUUID();

    // pulling before initializing will break something, but it shouldn't be able to happen if i do everything properly
    this.lastPulled = -1;
  }

  async init(): Promise<string> {
    let response = (await this.#sendMessage("start")) as StartResponse;

    this.lastPulled = response.currentId;

    return response.document;
  }

  async sendPush(changes: Change[]): Promise<void> {
    let message: PushMessage = {
      type: "push",
      changes,
    };

    await this.#sendMessage(message);
  }

  async sendPull(): Promise<Change[]> {
    let message: PullMessage = {
      type: "pull",
      lastPulled: this.lastPulled,
    };

    let response = (await this.#sendMessage(message)) as PullResponse;

    this.lastPulled = response.currentId;

    return response.pulledChanges;
  }
}
