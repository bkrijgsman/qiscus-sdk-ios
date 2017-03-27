//
//  QiscusAsyncImageView.swift
//  QiscusAsyncImageView
//
//  Created by Ahmad Athaullah on 6/30/16.
//  Copyright © 2016 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Foundation

var cache = NSCache<NSString,UIImage>()
open class QiscusAsyncImageView: UIImageView {
    
    
}
public extension UIImageView {
    public func loadAsync(_ url:String, placeholderImage:UIImage? = nil, header : [String : String] = [String : String](), useCache:Bool = true){
        var returnImage = UIImage()
        if placeholderImage != nil {
            returnImage = placeholderImage!
            self.image = returnImage
        }
        imageForUrl(url: url, header: header, useCache: useCache, completionHandler:{(image: UIImage?, url: String) in
            if let returnImage = image{
                self.image = returnImage
            }
        })
    }
    public func loadAsync(fromLocalPath localPath:String, placeholderImage:UIImage? = nil){
        var returnImage = UIImage()
        if placeholderImage != nil {
            returnImage = placeholderImage!
            self.image = returnImage
        }
        DispatchQueue.global().async {
            if let image = UIImage(contentsOfFile: localPath){
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
    
    // func imageForUrl
    //  Modified from ImageLoader.swift Created by Nate Lyman on 7/5/14.
    //              git: https://github.com/natelyman/SwiftImageLoader
    //              Copyright (c) 2014 NateLyman.com. All rights reserved.
    //
    func imageForUrl(url urlString: String, header: [String : String] = [String : String](), useCache:Bool = false, completionHandler:@escaping (_ image: UIImage?, _ url: String) -> ()) {
        
        DispatchQueue.global().async(execute: {()in
            
            let image = cache.object(forKey: urlString as NSString)
            
            
            if useCache && (image != nil) {
                DispatchQueue.main.async(execute: {() in
                    completionHandler(image, urlString)
                })
                return
            }else{
                if let url = URL(string: urlString){
                    var urlRequest = URLRequest(url: url)
                    
                    for (key, value) in header {
                        urlRequest.addValue(value, forHTTPHeaderField: key)
                    }
                    
                    let downloadTask = URLSession.shared.dataTask(with: urlRequest, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
                    
                        if (error != nil) {
                            completionHandler(nil, urlString)
                            print("[QiscusAsyncImageView] Error: \(error)")
                            Qiscus.printLog(text: "[QiscusAsyncImageView] : \(error)")
                            return
                        }
                        
                        if let data = data {
                            if let image = UIImage(data: data) {
                                if useCache{
                                    cache.setObject(image, forKey: urlString as NSString)
                                }else{
                                    cache.removeObject(forKey: urlString as NSString)
                                }
                                DispatchQueue.main.async(execute: {() in
                                    completionHandler(image, urlString)
                                })
                            }else{
                                DispatchQueue.main.async(execute: {() in
                                    completionHandler(nil, urlString)
                                })
                                Qiscus.printLog(text: "[QiscusAsyncImageView] : Can't get image from URL: \(url)")
                            }
                            return
                        }
                        return ()
                        
                    })
                    downloadTask.resume()
                }
            }
        })
    }
}
public extension UIImage {
    public class func clearAllCache(){
        cache.removeAllObjects()
    }
    public class func clearCachedImageForURL(_ urlString:String){
        cache.removeObject(forKey: urlString as NSString)
    }
    public class func resizeImage(_ image: UIImage, toFillOnImage: UIImage) -> UIImage {
        
        var scale:CGFloat = 1
        var newSize:CGSize = toFillOnImage.size
        
        if image.size.width > image.size.height{
            scale = image.size.width / image.size.height
            newSize.width = toFillOnImage.size.width
            newSize.height = toFillOnImage.size.height / scale
        }else{
            scale = image.size.height / image.size.width
            newSize.height = toFillOnImage.size.height
            newSize.width = toFillOnImage.size.width / scale
        }
        
        var scaleFactor = newSize.width / image.size.width
        
        
        if (image.size.height * scaleFactor) < toFillOnImage.size.height{
            scaleFactor = scaleFactor * (toFillOnImage.size.height / (image.size.height * scaleFactor))
        }
        if (image.size.width * scaleFactor) < toFillOnImage.size.width{
            scaleFactor = scaleFactor * (toFillOnImage.size.width / (image.size.width * scaleFactor))
        }
        
        UIGraphicsBeginImageContextWithOptions(toFillOnImage.size, false, scaleFactor)
        
        var xPos:CGFloat = 0
        if (image.size.width * scaleFactor) > toFillOnImage.size.width {
            xPos = ((image.size.width * scaleFactor) - toFillOnImage.size.width) / 2
        }
        var yPos:CGFloat = 0
        if (image.size.height * scale) > toFillOnImage.size.height{
            yPos = ((image.size.height * scaleFactor) - toFillOnImage.size.height) / 2
        }
        image.draw(in: CGRect(x: 0 - xPos,y: 0 - yPos, width: image.size.width * scaleFactor, height: image.size.height * scaleFactor))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
}
