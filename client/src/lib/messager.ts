import { randomUUID, type UUID } from "crypto";
import type WebSocketClient from "websocket-async";

type Change =
  | {
      type: "insert";
      position: Number;
      text: String;
      from: String;
    }
  | {
      type: "delete";
      position: Number;
      amount: Number;
      from: String;
    }
  | null;

type StartMessage = "start";
type StartResponse = {
  type: "start";
  document: String;
  currentId: Number;
};

type PushMessage = {
  type: "push";
  changes: [Change];
};
type PushResponse = "push";

type PullMessage = {
  type: "pull";
  lastPulled: Number;
};
type PullResponse = {
  type: "pull";
  pulledChanges: [Change];
  currentId: Number;
};

type Message = StartMessage | PullMessage | PushMessage;

type Response = StartResponse | PullResponse | PushResponse;

export class Messager {
  websocket: WebSocketClient;
  clientId: UUID;
  lastPulled: Number;

  // probably could have gotten away with using fetch requests for this instead of websocket
  #sendMessage = async (message: Message): Promise<Response> => {
    this.websocket.send(JSON.stringify(message));

    const response = await this.websocket.receive();

    return JSON.parse(response) as Response;
  };

  constructor(websocket: WebSocketClient) {
    this.websocket = websocket;
    this.clientId = randomUUID();

    // pulling before initializing will break something, but it shouldn't be able to happen if i do everything properly
    this.lastPulled = -1;
  }

  async init(): Promise<String> {
    let response = (await this.#sendMessage("start")) as StartResponse;

    this.lastPulled = response.currentId;

    return response.document;
  }

  async push(changes: [Change]): Promise<void> {
    let message: PushMessage = {
      type: "push",
      changes,
    };

    await this.#sendMessage(message);
  }

  async pull(): Promise<[Change]> {
    let message: PullMessage = {
      type: "pull",
      lastPulled: this.lastPulled,
    };

    let response = (await this.#sendMessage(message)) as PullResponse;

    this.lastPulled = response.currentId;

    return response.pulledChanges;
  }
}
