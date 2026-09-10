function AprRC:CaptureRecordingContext()
    return { route = AprRCData.CurrentRoute, session = self.recordingSession or 0 }
end

function AprRC:IsRecordingContext(context)
    return self.settings.profile.enableAddon and self.settings.profile.recordBarFrame.isRecording
        and (not context or (context.route == AprRCData.CurrentRoute and context.session == (self.recordingSession or 0)))
end

function AprRC:ResetRecordingSession()
    self.recordingSession = (self.recordingSession or 0) + 1
    self.CurrentTaxiNode = nil
    self.CurrentTaxiNodes = nil
    self.isOnTaxi = false
    AprRCData.BeforePortal = {}
    if self.event and self.event.ResetTracking then self.event:ResetTracking() end
end
