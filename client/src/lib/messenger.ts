import type { UUID } from "crypto";
import { Reciever } from "./reciever";
import { editors, title } from "../stores";

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

// i could probably do away with this start message with ssr...
type StartMessage = "start";
type StartResponse = {
  type: "start";
  title: string;
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
  _reciever: Reciever;
  _lastPulled: number;
  clientId: UUID;

  constructor(websocket: WebSocket) {
    this._reciever = new Reciever(websocket);
    this.clientId = self.crypto.randomUUID();

    this._reciever.registerEvent("editor", (data) => {
      editors.set(data.editors);
    });

    // pulling before initializing will break something, but it shouldn't be able to happen if i do everything properly
    this._lastPulled = -1;
  }

  async init(): Promise<string> {
    let response = (await this._reciever.call("start")) as StartResponse;

    this._lastPulled = response.currentId;
    title.set(response.title);

    return response.document;
  }

  sendPush(changes: Change[]): void {
    let message: PushMessage = {
      type: "push",
      changes,
    };

    this._reciever.call(message);
  }

  async sendPull(): Promise<Change[]> {
    let message: PullMessage = {
      type: "pull",
      lastPulled: this._lastPulled,
    };

    let response = (await this._reciever.call(message)) as PullResponse;

    this._lastPulled = response.currentId;

    return response.pulledChanges;
  }
}
