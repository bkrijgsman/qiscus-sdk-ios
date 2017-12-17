//
//  QChatCell.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

protocol ChatCellDelegate {
    func didTapCell(onComment comment: QComment)
    func didTouchLink(onComment comment: QComment)
    func didTapPostbackButton(onComment comment: QComment, index:Int)
    func didTapAccountLinking(onComment comment: QComment)
    func didTapSaveContact(onComment comment: QComment)
    func didTapCardButton(onComment comment:QComment, index:Int)
    func didShare(comment: QComment)
    func didForward(comment: QComment)
    func didReply(comment:QComment)
    func getInfo(comment:QComment)
    func didTapFile(comment:QComment)
}
public class QChatCell: UICollectionViewCell, QCommentDelegate {
    
    var delegate: ChatCellDelegate?
    
    private var commentRaw:QComment?
        
    public var comment:QComment?{
        get{
            return self.commentRaw
        }
    }
    var linkTextAttributes:[String: Any]{
        get{
            var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            var underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            if self.comment?.senderEmail == QiscusMe.shared.email{
                foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
                underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
            }
            return [
                NSForegroundColorAttributeName: foregroundColorAttributeName,
                NSUnderlineColorAttributeName: underlineColorAttributeName,
                NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue,
                NSFontAttributeName: Qiscus.style.chatFont
            ]
        }
    }
    override public func awakeFromNib() {
        super.awakeFromNib()
        let resendMenuItem: UIMenuItem = UIMenuItem(title: "Resend", action: #selector(QChatCell.resend))
        let deleteMenuItem: UIMenuItem = UIMenuItem(title: "Delete", action: #selector(QChatCell.deleteComment))
        let replyMenuItem: UIMenuItem = UIMenuItem(title: "Reply", action: #selector(QChatCell.reply))
        let forwardMenuItem: UIMenuItem = UIMenuItem(title: "Forward", action: #selector(QChatCell.forward))
        let shareMenuItem: UIMenuItem = UIMenuItem(title: "Share", action: #selector(QChatCell.share))
        let infoMenuItem: UIMenuItem = UIMenuItem(title: "Info", action: #selector(QChatCell.info))
        
        let menuItems:[UIMenuItem] = [resendMenuItem,deleteMenuItem,replyMenuItem,forwardMenuItem,shareMenuItem,infoMenuItem]
        
        UIMenuController.shared.menuItems = menuItems
    }
    @objc private func messageStatusNotif(_ notification: Notification){
        if let userInfo = notification.userInfo {
            if let commentData = userInfo["comment"] as? QComment {
                if let currentComment = self.comment {
                    if commentData.isInvalidated || currentComment.isInvalidated{ return }
                    if self.comment?.uniqueId == commentData.uniqueId {
                        self.updateStatus(toStatus: commentData.status)
                    }
                }
            }
        }
    }
    func setupCell(){
        // implementation will be overrided on child class
    }


    func updateStatus(toStatus status:QCommentStatus){
        // implementation will be overrided on child class
    }
    open func resend(){
        if let room = QRoom.room(withId: self.comment!.roomId) {
            if self.comment!.type == .text {
                room.updateCommentStatus(inComment: self.comment!, status: .sending)
                room.post(comment: self.comment!)
            }else{
                if let file = self.comment!.file {
                    if file.url.contains("http") {
                        room.updateCommentStatus(inComment: self.comment!, status: .sending)
                        room.post(comment: self.comment!)
                    }else{
                        if QFileManager.isFileExist(inLocalPath: file.localPath) {
                            room.upload(comment: self.comment!, onSuccess: { (roomTarget, commentTarget) in
                                roomTarget.post(comment: commentTarget)
                            }, onError: { (_, _, error) in
                                Qiscus.printLog(text: "error reupload file")
                            })
                        }
                    }
                }
            }
        }
    }
    open func reply(){
        self.delegate?.didReply(comment: self.comment!)
    }
    public func forward(){
        self.delegate?.didForward(comment: self.comment!)
        if let chatView = Qiscus.shared.chatViews[self.comment!.roomId]{
            chatView.forward(comment: self.comment!)
        }
    }
    open func deleteComment(){
        if let room = QRoom.room(withId: self.comment!.roomId){
            room.deleteComment(comment: self.comment!)
        }
    }
    open func info(){
        self.delegate?.getInfo(comment: self.comment!)
    }
    open func share(){
        if let comment = self.comment {
            self.delegate?.didShare(comment: comment)
        }
    }
    open func showFile(){
        if let c = self.comment {
            self.delegate?.didTapFile(comment: c)
        }
    }
    
    func clearContext(){
        
    }
    
    public func commentChanged(){
        //print("comment changed")
    }

    public func getBallon()->UIImage?{
        var balloonImage:UIImage? = nil
        var edgeInset = UIEdgeInsetsMake(13, 13, 13, 28)
        
        switch self.comment!.cellPos {
        case .single, .last:
            if self.comment?.senderEmail == QiscusMe.shared.email {
                balloonImage = Qiscus.style.assets.rightBallonLast
            }else{
                edgeInset = UIEdgeInsetsMake(13, 28, 13, 13)
                balloonImage = Qiscus.style.assets.leftBallonLast
            }
            break
        default:
            if self.comment?.senderEmail == QiscusMe.shared.email {
                balloonImage = Qiscus.style.assets.rightBallonNormal
            }else{
                edgeInset = UIEdgeInsetsMake(13, 28, 13, 13)
                balloonImage = Qiscus.style.assets.leftBallonNormal
            }
            break
        }
        
        return balloonImage?.resizableImage(withCapInsets: edgeInset, resizingMode: .stretch).withRenderingMode(.alwaysTemplate)
    }
    public func willDisplayCell(){
        
    }
    public func endDisplayingCell(){
    
    }
    public func cellWidthChanged(){
    
    }
    public func downloadingMedia(){
        // implementation will be overrided on child class
    }
    public func downloadFinished(){
    
    }
    public func uploadingMedia(){
    
    }
    public func uploadFinished(){
        
    }
    public func positionChanged(){
    
    }
    public func updateUserName(){
    
    }
    internal func unbindData(){
        if let data = self.comment {
            data.delegate = nil
        }
    }
    public func setData(comment:QComment){
        var oldUniqueId:String?
        if let oldComment = self.comment {
            oldComment.delegate = nil
            oldUniqueId = oldComment.uniqueId
        }
        if let cache = QComment.cache[comment.uniqueId]{
            self.commentRaw = cache
        }else{
            QComment.cache[comment.uniqueId] = comment
            self.commentRaw = comment
        }
        self.comment!.delegate = self
        if let uId = oldUniqueId {
            if uId != comment.uniqueId {
                self.commentChanged()
            }
        }else{
            self.commentChanged()
        }
    }
    
    // MARK: - commentDelegate
    public func comment(didChangeStatus comment:QComment, status:QCommentStatus){
        if comment.uniqueId == self.comment?.uniqueId{
            self.updateStatus(toStatus: status)
        }
    }
    public func comment(didChangePosition comment:QComment, position:QCellPosition){}
    
    // Audio comment delegate
    public func comment(didChangeDurationLabel comment:QComment, label:String){}
    public func comment(didChangeCurrentTimeSlider comment:QComment, value:Float){}
    public func comment(didChangeSeekTimeLabel comment:QComment, label:String){}
    public func comment(didChangeAudioPlaying comment:QComment, playing:Bool){}
    
    // File comment delegate
    public func comment(didDownload comment:QComment, downloading:Bool){
        
    }
    public func comment(didUpload comment:QComment, uploading:Bool){}
    public func comment(didChangeProgress comment:QComment, progress:CGFloat){}
    
    
}
