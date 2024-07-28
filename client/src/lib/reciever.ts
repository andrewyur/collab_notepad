// a class to handle multiplexed synchronous calls and server events, inspired by websocket-async
// will be difficult to make this type safe, but for my purposes it is fine
type ServerResponse = {
  id: string;
  response: { [key: string]: any };
};

export class Reciever {
  _websocket: WebSocket;
  _events: {
    [key: string]: (data: any) => void;
  };
  _waiting: {
    id: string;
    resolve: (data: any) => void;
    reject: (reason: any) => void;
  }[];

  constructor(websocket: WebSocket) {
    this._websocket = websocket;
    this._events = {};
    this._waiting = [];
    websocket.addEventListener("message", (e) => {
      let message = JSON.parse(e.data);
      if ("id" in message) {
        message = message as ServerResponse;
        this._waiting
          .find((req) => (req.id = message.id))
          ?.resolve(message.response);
        this._waiting = this._waiting.filter((req) => req.id != message.id);
      } else {
        if (this._events[message.type]) this._events[message.type](message);
      }
    });
    websocket.addEventListener("close", (e: CloseEvent) => {
      this._waiting.forEach((req) => req.reject(e));
    });
  }

  registerEvent(type: string, action: (data: any) => void) {
    this._events[type] = action;
  }

  call(message: any) {
    let id = self.crypto.randomUUID();
    this._websocket.send(
      JSON.stringify({
        id,
        message,
      })
    );

    let promise = new Promise((resolve, reject) => {
      this._waiting = [
        ...this._waiting,
        {
          id,
          resolve,
          reject,
        },
      ];
    });

    return promise;
  }
}
