//
// Created by Daniel Coleman on 11/20/21.
//

import Foundation
import Combine

public protocol SerializingPubChannel {

    func publish<Event: Encodable>(_ event: Event)
}

public protocol SerializingSubChannel {

    func subscribe<Event: Decodable>(_ handler: @escaping (Event) -> Void) -> Subscription
}

public typealias SerializingChannel = SerializingPubChannel & SerializingSubChannel

public protocol SerializedPubChannel {

    associatedtype Output

    func publish(_ payload: Output)
}

public protocol SerializedSubChannel {

    associatedtype Input

    func subscribe(_ handler: @escaping (Input) -> Void) -> Subscription
}

public typealias SerializedChannel = SerializedPubChannel & SerializedSubChannel

extension SimpleChannel : SerializedChannel {

    public typealias Output = Data
    public typealias Input = Data
}

class SimpleSerializingChannel<Decoder: TopLevelDecoder, Encoder: TopLevelEncoder> : SerializingChannel where Decoder.Input == Encoder.Output {

    init<UnderlyingChannel: SerializedChannel>(
        underlyingChannel: UnderlyingChannel,
        decoder: Decoder,
        encoder: Encoder
    ) where UnderlyingChannel.Input == UnderlyingChannel.Output, UnderlyingChannel.Input == Decoder.Input {

        self.publishImp = underlyingChannel.publish

        self.decoder = decoder
        self.encoder = encoder

        self.underlyingSubscription = underlyingChannel.subscribe(channel.publish)
    }

    func publish<Event: Encodable>(_ event: Event) {

        guard let payload = try? encoder.encode(event) else { return }

        self.publishImp(payload)
    }

    func subscribe<Event: Decodable>(_ handler: @escaping (Event) -> Void) -> Subscription {

        let decoder = self.decoder

        return channel.subscribe { (payload: Decoder.Input) in

            guard let event = try? decoder.decode(Event.self, from: payload) else {
                return
            }

            handler(event)
        }
    }

    private let publishImp: (Encoder.Output) -> Void
    private var underlyingSubscription: Subscription!

    private let decoder: Decoder
    private let encoder: Encoder

    private let channel = SimpleChannel()
}

typealias SimpleJSONChannel = SimpleSerializingChannel<JSONDecoder, JSONEncoder>

extension SimpleSerializingChannel where Decoder == JSONDecoder, Encoder == JSONEncoder {

    convenience init<UnderlyingChannel: SerializedChannel>(
        underlyingChannel: UnderlyingChannel
    ) where UnderlyingChannel.Input == UnderlyingChannel.Output, UnderlyingChannel.Input == Decoder.Input {

        self.init(
            underlyingChannel: underlyingChannel,
            decoder: JSONDecoder(),
            encoder: JSONEncoder()
        )
    }
}