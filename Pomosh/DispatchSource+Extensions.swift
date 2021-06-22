/*
Copyright © 2020 Apple Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


Abstract:
`DispatchSource.TimePublisher` is a publisher for a `DispatchSource` timer.
*/

import Foundation
import Combine

extension DispatchSource {
    public struct TimerPublisher: Publisher {
        public typealias Output = DispatchTime
        public typealias Failure = Never

        public let deadline: DispatchTime
        public let interval: DispatchTimeInterval
        public let leeway: DispatchTimeInterval
        public let flags: DispatchSource.TimerFlags
        public let queue: DispatchQueue?

        public init(deadline: DispatchTime,
                    repeating interval: DispatchTimeInterval = .never,
                    leeway: DispatchTimeInterval = .nanoseconds(0), flags: DispatchSource.TimerFlags = [], queue: DispatchQueue? = nil) {
            self.deadline = deadline
            self.interval = interval
            self.leeway = leeway
            self.flags = flags
            self.queue = queue
        }

        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            subscriber.receive(subscription: Subscription(subscriber,
                                                          deadline: deadline, repeating: interval, leeway: leeway, flags: flags, queue: queue))
        }

        private final class Subscription<Downstream: Subscriber>: Combine.Subscription where Downstream.Failure == Failure,
                                                                                             Downstream.Input == Output {
            var downstream: Downstream?
            let lock = os_unfair_lock_t.allocate(capacity: 1)
            let deadline: DispatchTime
            let interval: DispatchTimeInterval
            let leeway: DispatchTimeInterval
            let flags: DispatchSource.TimerFlags
            var queue: DispatchQueue?
            var timer: DispatchSourceTimer?
            var pending = Subscribers.Demand.none

            init(_ downstream: Downstream,
                 deadline: DispatchTime,
                 repeating interval: DispatchTimeInterval, leeway: DispatchTimeInterval, flags: DispatchSource.TimerFlags, queue: DispatchQueue?) {
                self.deadline = deadline
                self.interval = interval
                self.leeway = leeway
                self.flags = flags
                self.queue = queue
                self.downstream = downstream

                lock.initialize(to: os_unfair_lock_s())
            }

            deinit {
                lock.deallocate()
            }

            func fired() {
                guard let downstream = downstream else {
                    return
                }

                let fire: Bool

                os_unfair_lock_lock(lock)

                if pending > .none {
                    pending -= 1
                    fire = true
                } else {
                    fire = false
                }

                os_unfair_lock_unlock(lock)

                if fire {
                    let additional = downstream.receive(.now())
                    os_unfair_lock_lock(lock)
                    pending += additional
                    os_unfair_lock_unlock(lock)
                }
            }

            func request(_ demand: Subscribers.Demand) {
                os_unfair_lock_lock(lock)

                let timer: DispatchSourceTimer
                let needsResume: Bool

                if let tempTimer = self.timer {
                    timer = tempTimer
                    needsResume = false
                } else {
                    timer = DispatchSource.makeTimerSource(flags: flags, queue: queue)
                    timer.setEventHandler {
                        self.fired()
                    }
                    self.timer = timer
                    needsResume = true
                }

                pending += demand

                os_unfair_lock_unlock(lock)

                if needsResume {
                    timer.schedule(deadline: deadline, repeating: interval, leeway: leeway)
                    timer.resume()
                }
            }

            func cancel() {
                os_unfair_lock_lock(lock)

                let timer = self.timer
                self.timer = nil
                queue = nil

                os_unfair_lock_unlock(lock)

                timer?.cancel()
            }
        }
    }
}

public typealias DispatchTimePublisher = Publishers.MakeConnectable<Publishers.Share<DispatchSource.TimerPublisher>>

extension Publishers {
    static func `repeat`(interval: DispatchTimeInterval, queue: DispatchQueue? = DispatchQueue(label: "DispatchTimePublisher.dispatchQueue")) -> DispatchTimePublisher {
        return DispatchSource.TimerPublisher(deadline: .now() + interval, repeating: interval, queue: queue).share().makeConnectable()
    }

    static func `repeat`(interval: TimeInterval, queue: DispatchQueue? = DispatchQueue(label: "DispatchTimePublisher.dispatchQueue")) -> DispatchTimePublisher {
        let dispatchTimeinterval: DispatchTimeInterval = .milliseconds(Int(interval * 1000.0))
        return self.repeat(interval: dispatchTimeinterval, queue: queue)
    }
}
