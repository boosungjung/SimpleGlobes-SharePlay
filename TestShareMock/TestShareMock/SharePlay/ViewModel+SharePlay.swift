//
//  SharePlay.swift
//  VisionSharePlayTest
//
//  Created by BooSung Jung on 30/7/2024.
//
import SwiftUI
import GroupActivities
import SharePlayMock
import Combine


/// User can break out of the spatial persona and if they want to return to the spatial persona format they can press the digital crown

extension ViewModel {
    
    
    func configureGroupSessions(){
        
        Task(priority: .high) {
            for await groupSession in MyGroupActivity.sessions() {
                
                // set group session messenger
                self.groupSession = groupSession
#if DEBUG
                let messenger = GroupSessionMessengerMock(session: groupSession)
#else
                let messenger = GroupSessionMessenger(session: groupSession)
#endif
                
                self.messenger = messenger
                
                groupSession.$state.sink {
                    // this Tearsdown existing group session
                    if case .invalidated = $0 {
                        self.cleanupGroupSession()
                    }
                }
                .store(in: &self.subscriptions)
                // store the subscription in the subscriptions set
                
                // sink observes and reacts to changes in the group session activeParticipants
                groupSession.$activeParticipants
                    .sink {
                        
                        let newParticipants = $0.subtracting(groupSession.activeParticipants)
                        Task {
                            // if there is a new participant send the activity state to only the new participants
                            // https://developer.apple.com/videos/play/wwdc2021/10187/
                            // 19:33
                            try? await messenger.send(self.activityState,
                                                      to: .only(newParticipants))
                            
                            
                        }
                    }
                    .store(in: &self.subscriptions)
                
                
                // listen to messages from the group session
                self.tasks.insert(
                    Task {
                        for await (message, _) in messenger.messages(of: ActivityState.self) {
                            self.receive(message)
                        }
                    }
                )
                
                
                
                /// For visionOS
                self.tasks.insert(
                    Task {
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            for await localParticipantState in systemCoordinator.localParticipantStates {
                                // if it is spacial share play do something
                                
                            }
                        }
                    }
                )
                
                self.tasks.insert(
                    Task{
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            for await immersionStyle in systemCoordinator.groupImmersionStyle{
                                if let immersionStyle {
                                    // open an immersive space with the same immersion style
                                } else{
                                    // Dismiss the immserive space
                                }
                            }
                        }
                        
                    }
                )
                self.tasks.insert(
                    Task {
                        @MainActor in
                        sharePlayEnabled = true
                    }
                )
                
                
                // this section of code assigns the systemCoordinator to the groupSession
                self.tasks.insert(
                    Task {
                        if let systemCoordinator = await groupSession.systemCoordinator {
                            var configuration = SystemCoordinator.Configuration()
                            
                            //enable support
                            configuration.supportsGroupImmersiveSpace = true
                            
                            // https://developer.apple.com/videos/play/wwdc2023/10087/?time=248
                            // we are using .surround since we are viewing a globe
                            if #available(visionOS 2.0, *) {
                                configuration.spatialTemplatePreference = .surround.contentExtent(200)
                            } else {
                                // Fallback on earlier versions
                            }
                            systemCoordinator.configuration = configuration
                            groupSession.join()
                        }
                    }
                )
            }
        }
    }
    
    
    // MARK: Manual toggle for shareplay
    func toggleSharePlay() {
        if (!self.sharePlayEnabled) {
            startSharePlay()
        } else {
            endSharePlay()
        }
    }
    
    func startSharePlay() {
        Task {
            let activity = MyGroupActivity()
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                } catch {
                    print("SharePlay unable to activate the activity: \(error)")
                }
            case .activationDisabled:
                print("SharePlay group activity activation disabled")
            case .cancelled:
                print("SharePlay group activity activation cancelled")
            @unknown default:
                print("SharePlay group activity activation unknown case")
            }
        }
    }
    
    func endSharePlay() {
        self.groupSession?.end()
//        sharePlayEnabled = false
    }
    
    func sendMessage() {
        // sends the state of activity
        Task{
            try? await self.messenger?.send(self.activityState)
        }
    }
    
    func receive(_ message: ActivityState) {
        Task { @MainActor in
            // Check if the received state is actually different from the current state
//            guard self.activityState != message else {
//                return
//            }
            
            // Update the state and reflect changes in the UI
            self.activityState = message
            self.updateEntity()
        }
    }
    
    //    #warning("change name to updateEntity")
    @MainActor
    private func updateEntity() {

//        guard let configuration = activityState.globeConfiguration else{
//            return
//        }
        if globeEntity == nil {
          
           

        }
        guard let openImmersiveSpaceAction = self.openImmersiveSpaceAction else {
            return
        }
        // isVisible and isLoading should be both false for other participants initially
        if !configuration.isVisible && self.activityState.loadGlobe == true && !configuration.isLoading{
            load(globe: configuration.globe, openImmersiveSpaceAction: openImmersiveSpaceAction)
        }

        
        if configuration.isVisible && self.activityState.loadGlobe == false{
            hideGlobe()
        }
        
     
        
        if let tempTranslation = self.activityState.tempTranslation {
            let orientation = tempTranslation.orientation!
            let position = tempTranslation.position ?? .zero
            globeEntity?.animateTransform(orientation: orientation, position: position)
        }

    }
    
    

    private func cleanupGroupSession() {
        // reset the group session, this is called when
        sharePlayEnabled = false
        self.messenger = nil
        self.tasks.forEach { $0.cancel() }
        self.tasks = []
        self.subscriptions = []
        self.groupSession = nil
        self.activityState = ActivityState() // Reset activity state
        //           self.spatialSharePlaying = false // Reset spatialSharePlaying
    }
    
    private enum ActivationError: Error {
        case failed, disabled, cancelled, unknown
    }
}
