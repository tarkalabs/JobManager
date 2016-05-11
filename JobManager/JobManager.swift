//
//  JobManager.swift
//  JobManager
//
//  Created by Prasanna on 10/05/16.
//  Copyright © 2016 Tarka Labs. All rights reserved.
//

import Foundation

let JobStatusChangedNotification = "JobStatusChangedNotification"

class Job: NSOperation {
  
  enum UserState: CustomStringConvertible {
    case Queued
    case Processing
    case Cancelled
    case Finished
    
    var description: String {
      switch self {
      case Queued:
        return "Queued"
      case Processing:
        return "Processing"
      case Cancelled:
        return "Cancelled"
      case Finished:
        return "Finished"
      }
    }
  }
  
  enum JobState: CustomStringConvertible {
    case Ready
    case Executing
    case Finished
    
    func keyPath() -> String {
      switch self {
      case Ready:
        return "isReady"
      case Executing:
        return "isExecuting"
      case Finished:
        return "isFinished"
      }
    }
    var description: String {
      switch self {
      case Ready:
        return "Ready"
      case Executing:
        return "Executing"
      case Finished:
        return "Finished"
      }
    }
  }
  
  var jobState = JobState.Ready {
    willSet {
      willChangeValueForKey(newValue.keyPath())
      willChangeValueForKey(jobState.keyPath())
    }
    didSet {
      didChangeValueForKey(oldValue.keyPath())
      didChangeValueForKey(jobState.keyPath())
      
      notifyChange()
    }
  }
  
  var userState: UserState {
    if cancelled {
      return .Cancelled
    }
    
    switch jobState {
    case .Ready: return .Queued
    case .Executing: return .Processing
    case .Finished: return .Finished
    }
  }
  
  var id: Int {
    return ObjectIdentifier(self).hashValue
  }
  
  var hasStarted = false
  var didCopy = false
  
  var _progress = 0
  var progress: Int {
    get {
      return _progress
    }
    set {
      _progress = newValue
      notifyChange()
    }
  }
  
  override var ready: Bool {
    return super.ready && jobState == .Ready
  }
  
  override var executing: Bool {
    return jobState == .Executing
  }
  
  override var finished: Bool {
    return jobState == .Finished
  }
  
  override var asynchronous: Bool {
    return true
  }
  
  override var description: String {
    let name = self.name ?? ""
    return "\(id) - \(name) - \(userState)"
  }
  
  func notifyChange() {
    NSNotificationCenter.defaultCenter().postNotificationName(JobStatusChangedNotification, object: self)
  }
  
  override func cancel() {
    if canCancel {
      super.cancel()
      notifyChange()
    }
  }

  var canClear: Bool {
    return (hasStarted == false && userState == .Cancelled)
      || jobState == .Finished
  }
  
  var canCancel: Bool {
    return userState == .Queued
      || userState == .Processing
  }
  
  var canRetry: Bool {
    return userState == .Cancelled
  }
  
  var canPause: Bool {
    return userState == .Processing
      || userState == .Queued
      || userState == .Cancelled
  }
  
  func copyForRetry() -> Job? {
    return nil
  }
  
}

class JobManager: NSObject {
  
  var jobQueue = NSOperationQueue()
  var jobs = [Job]()
  var paused = false
  
  private var observeContext = 0
  private var jobStatusChangedNotificationObserver: AnyObject?
  
  var didInsertJob: ((index: Int, job: Job) -> ())?
  var didRemoveJob: ((index: Int, job: Job) -> ())?
  var didUpdateJob: ((index: Int, job: Job) -> ())?
  
  override init() {
    super.init()
    
    jobQueue.maxConcurrentOperationCount = 2
    jobQueue.addObserver(self, forKeyPath: "jobs", options: .New, context: &observeContext)
    
    jobStatusChangedNotificationObserver = NSNotificationCenter.defaultCenter().addObserverForName(JobStatusChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { notification in
      guard let job = notification.object as? Job else {
        return
      }
      self.updateJob(job)
    }
  }
  
  deinit {
    jobQueue.removeObserver(self, forKeyPath: "jobs", context: &observeContext)
    
    if jobStatusChangedNotificationObserver != nil {
      NSNotificationCenter.defaultCenter().removeObserver(jobStatusChangedNotificationObserver!)
    }
  }
  
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    if context == &observeContext {
      performSelectorOnMainThread(#selector(JobManager.reload), withObject: nil, waitUntilDone: false)
      return
    }
    
    super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
  }
  
  private func insertJob(job: Job) {
    self.jobs.append(job)
    didInsertJob?(index: jobs.count - 1, job: job)
  }
  
  private func updateJob(job: Job) {
    if let idx = jobs.indexOf(job) {
      didUpdateJob?(index: idx, job: job)
    }
  }
  
  func reload() {
    for job in jobQueue.operations as! [Job] {
      if self.jobs.indexOf(job) == nil && job.canClear == false && job.didCopy == false {
        insertJob(job)
      } else {
        updateJob(job)
      }
    }
  }
  
  func clear(job: Job) {
    guard job.canClear else {
      return
    }
    
    guard let idx = jobs.indexOf(job) else {
      return
    }
    
    jobs.removeAtIndex(idx)
    didRemoveJob?(index: idx, job: job)
  }
  
  func retry(job: Job) {
    guard let idx = jobs.indexOf(job) else {
      return
    }
    
    guard let newOp = job.copyForRetry() else {
      return
    }
    
    jobs.replaceRange(idx...idx, with: [ newOp ])
    jobQueue.addOperation(newOp)
  }
  
  func requeue() {
    for job in jobs {
      if job.userState == .Queued && !job.hasStarted {
        job.cancel()
        retry(job)
      }
    }
  }
  
  func add(job: Job) {
    jobQueue.addOperation(job)
    reload()
  }

  func clearAll() {
    for job in jobs {
      guard job.canClear else {
        continue
      }
      
      if let idx = jobs.indexOf(job) {
        jobs.removeAtIndex(idx)
        didRemoveJob?(index: idx, job: job)
      }
    }
  }
  
  func cancelAll() {
    jobQueue.cancelAllOperations()
  }
  
  subscript(index: Int) -> Job {
    return jobs[index]
  }
  
  var count: Int {
    return jobs.count
  }
  
}
