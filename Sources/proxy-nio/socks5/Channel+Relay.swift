//
//  File.swift
//  
//
//  Created by Purkylin King on 2021/1/23.
//

import NIO

extension Channel {
    func relay(peerChannel: Channel) -> EventLoopFuture<(Void)> {
        let (localGlue, peerGlue) = GlueHandler.matchedPair()
        return self.pipeline.addHandler(localGlue).and(peerChannel.pipeline.addHandler(peerGlue)).map { _ in
            return
        }
    }
}
