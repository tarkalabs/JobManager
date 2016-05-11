//
//  ViewController.swift
//  JobManager
//
//  Created by Prasanna on 10/05/16.
//  Copyright © 2016 Tarka Labs. All rights reserved.
//

import UIKit

class SampleJob: Job {
  
  override func start() {
    hasStarted = true
    
    if cancelled {
      jobState = .Finished
      return
    }
    
    jobState = .Executing
    
    while process() { }
    
    jobState = .Finished
  }
  
  func process() -> Bool {
    if cancelled {
      return false
    }
    
    usleep(1000000 / (arc4random_uniform(50) + 1))
    progress = progress + 1
    
    return progress < 100
  }
  
  override func copyForRetry() -> Job? {
    guard didCopy == false else {
      return nil
    }
    
    guard canRetry else {
      return nil
    }
    
    let job = SampleJob()
    job.name = self.name
    job.progress = self.progress
    didCopy = true
    return job
  }
  
}

class ViewController: UIViewController {
  
  var jobManager = JobManager()

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    jobManager.jobQueue.maxConcurrentOperationCount = 10
    addJob(nil)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: Add Job
  
  func addJob(sender: AnyObject?) {
    struct Static {
      static var counter = 0
    }
    
    let job = SampleJob()
    Static.counter = Static.counter + 1
    job.name = "Job \(Static.counter)"
    jobManager.add(job)
  }
  
  func cancelJob(job: Job) {
    if let jobtoCancel:Job = job {
      if jobtoCancel.canCancel {
        jobtoCancel.cancel()
      } else if jobtoCancel.canRetry {
        jobManager.retry(jobtoCancel)
      }
    }
  }
  
  func cellPressClear(job: Job) {
    if let jobtoClear:Job = job {
      jobManager.clear(jobtoClear)
    }
  }
  
  func cancelAllJobs(sender: AnyObject?) {
    jobManager.cancelAll()
  }
  
  func clearAllJobs(sender: AnyObject?) {
    jobManager.clearAll()
  }
  
  func addNewJobAndReorder(job: Job, atIndex: Int) {
    jobManager.jobs.removeAtIndex(atIndex)
    jobManager.jobs.insert(job, atIndex: atIndex)
    jobManager.requeue()
  }
}


