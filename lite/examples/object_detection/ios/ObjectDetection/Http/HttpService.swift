//
//  HttpService.swift
//  ObjectDetection
//
//  Created by Tomasz Domaracki on 07/06/2021.
//  Copyright © 2021 Y Media Labs. All rights reserved.
//


import SwiftyRequest


struct HttpService {
  let URL = "https://edym.prointegra.com.pl/save"
  
  func send(json: Data, completion:@escaping (_: Data?) -> Void) {
    let req = RestRequest(method: .post, url: URL, containsSelfSignedCert: true)
    req.messageBody = json
    req.responseString { response in
      completion(response.data)
    }
  }
}
