//
//  QiscusChatVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/18/16.
//  Copyright © 2016 Ahmad Athaullah. All rights reserved.
//

import UIKit
//import SJProgressHUD
import MobileCoreServices
import AVFoundation
import Photos
//import QToasterSwift
import ImageViewer

open class QiscusChatVC: UIViewController, ChatInputTextDelegate, QCommentDelegate, UIImagePickerControllerDelegate, UITableViewDelegate, UITableViewDataSource,UINavigationControllerDelegate, UIDocumentPickerDelegate, GalleryItemsDatasource{
    
    static let sharedInstance = QiscusChatVC()
    
    // MARK: - IBOutlet Properties
    @IBOutlet weak var inputBar: UIView!
    @IBOutlet weak var inputText: ChatInputText!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var welcomeView: UIView!
    @IBOutlet weak var welcomeText: UILabel!
    @IBOutlet weak var welcomeSubtitle: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var galeryButton: UIButton!
    @IBOutlet weak var archievedNotifView: UIView!
    @IBOutlet weak var archievedNotifLabel: UILabel!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var documentButton: UIButton!
    @IBOutlet weak var unlockButton: UIButton!
    @IBOutlet weak var emptyChatImage: UIImageView!
    
    // MARK: - Constrain
    @IBOutlet weak var minInputHeight: NSLayoutConstraint!
    @IBOutlet weak var welcomeViewHeight: NSLayoutConstraint!
    @IBOutlet weak var archievedNotifTop: NSLayoutConstraint!
    @IBOutlet weak var inputBarBottomMargin: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottomConstrain: NSLayoutConstraint!
    
    
    // MARK: - View Attributes
    var defaultViewHeight:CGFloat = 0
    var isPresence:Bool = false
    
    // MARK: - Data Properties
    var hasMoreComment = true
    var loadMoreControl = UIRefreshControl()
    var commentClient = QiscusCommentClient.sharedInstance
    var topicId = QiscusUIConfiguration.sharedInstance.topicId
    var users:[String] = QiscusUIConfiguration.sharedInstance.chatUsers
    //var room:QiscusRoom = QiscusRoom()
    var consultantId: Int = 0
    var consultantRate:Int = 0
    var comment = [[QiscusComment]]()
    var archived:Bool = QiscusUIConfiguration.sharedInstance.readOnly
    var rowHeight:[IndexPath: CGFloat] = [IndexPath: CGFloat]()
    var firstLoad = true
    
    var topColor = UIColor(red: 8/255.0, green: 153/255.0, blue: 140/255.0, alpha: 1.0)
    var bottomColor = UIColor(red: 23/255.0, green: 177/255.0, blue: 149/255.0, alpha: 1)
    var tintColor = UIColor.white
    var syncTimer:Timer?
    var selectedImage:UIImage = UIImage()
    var imagePreview:GalleryViewController?
    var loadWithUser:Bool = false
    var distincId:String? = nil
    
    var galleryItems = [UIImage]()
//TODO: - check this class
//    class QImageProvider: ImageProvider {
//        var images:[UIImage] = [UIImage]()
//        
//        var imageCount: Int {
//            return images.count
//        }
//        
//        func provideImage(_ completion: (UIImage?) -> Void) {
//            //completion(UIImage(named: "image_big"))
//        }
//        
//        func provideImage(atIndex index: Int, completion: (UIImage?) -> Void) {
//            completion(images[index])
//            QiscusChatVC.sharedInstance.selectedImage = images[index]
//            print("ganti image index: \(index)")
//        }
//    }
    
    //MARK: - external action
    open var unlockAction:(()->Void) = {}
    open var cellDelegate:QiscusChatCellDelegate?
    //var imageProvider = QImageProvider()
    
    
    var bundle:Bundle {
        get{
            return Qiscus.bundle
        }
    }
    var sendOnImage:UIImage?{
        get{
            return UIImage(named: "ic_send_on", in: self.bundle, compatibleWith: nil)?.localizedImage()
        }
    }
    var sendOffImage:UIImage?{
        get{
            return UIImage(named: "ic_send_off", in: self.bundle, compatibleWith: nil)?.localizedImage()
        }
    }
    var nextIndexPath:IndexPath{
        get{
            let indexPath = QiscusHelper.getNextIndexPathIn(groupComment:self.comment)
            return IndexPath(row: indexPath.row, section: indexPath.section)
        }
    }
    var isLastRowVisible: Bool {
        get{
            if self.comment.count > 0{
                let lastSection = self.comment.count - 1
                let lastRow = self.comment[lastSection].count - 1
                if let indexPaths = self.tableView.indexPathsForVisibleRows {
                    for indexPath in indexPaths {
                        if (indexPath as NSIndexPath).section == lastSection && (indexPath as NSIndexPath).row == lastRow{
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
    
    var lastVisibleRow:IndexPath?{
        get{
            if self.comment.count > 0{
                if let indexPaths = self.tableView.indexPathsForVisibleRows {
                    return indexPaths.last!
                }
            }
            return nil
        }
    }
    var UTIs:[String]{
        get{
            return ["public.jpeg", "public.png"/*,"com.compuserve.gif"*/,"public.text", "public.archive", "com.microsoft.word.doc", "com.microsoft.excel.xls", "com.microsoft.powerpoint.​ppt", "com.adobe.pdf"/*,"public.mpeg-4" */]
        }
    }
    
    fileprivate init() {
        super.init(nibName: "QiscusChatVC", bundle: Qiscus.bundle)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Lifecycle
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.emptyChatImage.image = Qiscus.image(named: "empty_messages")?.withRenderingMode(.alwaysTemplate)
        self.emptyChatImage.tintColor = QiscusColorConfiguration.sharedInstance.welcomeIconColor
        commentClient.commentDelegate = self
    }
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.emptyChatImage.image = Qiscus.image(named: "empty_messages")?.withRenderingMode(.alwaysTemplate)
        self.emptyChatImage.tintColor = QiscusColorConfiguration.sharedInstance.welcomeIconColor
        self.isPresence = false
        //self.syncTimer?.invalidate()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.isPresence = true
        firstLoad = true
        self.topicId = QiscusUIConfiguration.sharedInstance.topicId
        self.archived = QiscusUIConfiguration.sharedInstance.readOnly
        self.users = QiscusUIConfiguration.sharedInstance.chatUsers
        
        setupPage()
        loadData()
    }
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.comment = [[QiscusComment]]()
        self.tableView.reloadData()
    }
    // MARK: - Memory Warning
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Setup UI
    func setupPage(){
        archievedNotifView.isHidden = !archived
        self.archievedNotifTop.constant = 0
        if archived {
            self.archievedNotifLabel.text = QiscusTextConfiguration.sharedInstance.readOnlyText
        }else{
            self.archievedNotifTop.constant = 65
        }
        if Qiscus.sharedInstance.iCloudUpload {
            self.documentButton.isHidden = false
        }else{
            self.documentButton.isHidden = true
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.archievedNotifView.backgroundColor = QiscusColorConfiguration.sharedInstance.lockViewBgColor
        self.archievedNotifLabel.textColor = QiscusColorConfiguration.sharedInstance.lockViewTintColor
        let unlockImage = Qiscus.image(named: "ic_open_archived")?.withRenderingMode(.alwaysTemplate)
        self.unlockButton.setBackgroundImage(unlockImage, for: UIControlState())
        self.unlockButton.tintColor = QiscusColorConfiguration.sharedInstance.lockViewTintColor
        
        
        self.tableView.register(UINib(nibName: "ChatCellText",bundle: Qiscus.bundle), forCellReuseIdentifier: "cellText")
        self.tableView.register(UINib(nibName: "ChatCellMedia",bundle: Qiscus.bundle), forCellReuseIdentifier: "cellMedia")
        self.tableView.register(UINib(nibName: "ChatCellDocs",bundle: Qiscus.bundle), forCellReuseIdentifier: "cellDocs")
        
        //navigation Setup
        self.navigationItem.setTitleWithSubtitle(title: QiscusTextConfiguration.sharedInstance.chatTitle, subtitle:QiscusTextConfiguration.sharedInstance.chatSubtitle)
        //
        if !Qiscus.sharedInstance.isPushed{
            self.navigationController?.navigationBar.verticalGradientColor(topColor, bottomColor: bottomColor)
            self.navigationController?.navigationBar.tintColor = tintColor
        }
        
        let backButton = QiscusChatVC.backButton(self, action: #selector(QiscusChatVC.goBack))
        self.navigationItem.setHidesBackButton(true, animated: false)
        self.navigationItem.leftBarButtonItem = backButton
        
        // loadMoreControl
        self.loadMoreControl.addTarget(self, action: #selector(QiscusChatVC.loadMore), for: UIControlEvents.valueChanged)
        self.tableView.addSubview(self.loadMoreControl)
        
        // button setup
        sendButton.setBackgroundImage(self.sendOffImage, for: .disabled)
        sendButton.setBackgroundImage(self.sendOnImage, for: UIControlState())
        
        if inputText.value == "" {
            sendButton.isEnabled = false
        }else{
            sendButton.isEnabled = true
        }
        sendButton.addTarget(self, action: #selector(QiscusChatVC.sendMessage), for: .touchUpInside)
        
        //welcomeView Setup
        self.unlockButton.addTarget(self, action: #selector(QiscusChatVC.confirmUnlockChat), for: .touchUpInside)
        
        self.welcomeViewHeight.constant = (self.tableView.frame.height - 210) / 2
        self.welcomeText.text = QiscusTextConfiguration.sharedInstance.emptyTitle
        self.welcomeSubtitle.text = QiscusTextConfiguration.sharedInstance.emptyMessage
        
        self.inputText.textContainerInset = UIEdgeInsets.zero
        self.inputText.placeholder = QiscusTextConfiguration.sharedInstance.textPlaceholder
        self.inputText.chatInputDelegate = self
        self.defaultViewHeight = self.view.frame.height - (self.navigationController?.navigationBar.frame.height)! - QiscusHelper.statusBarSize().height
        
        // upload button setup
        self.galeryButton.addTarget(self, action: #selector(self.uploadImage), for: .touchUpInside)
        self.cameraButton.addTarget(self, action: #selector(QiscusChatVC.uploadFromCamera), for: .touchUpInside)
        self.documentButton.addTarget(self, action: #selector(QiscusChatVC.iCloudOpen), for: .touchUpInside)
        
        // Keyboard stuff.
        let center: NotificationCenter = NotificationCenter.default
        center.addObserver(self, selector: #selector(QiscusChatVC.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        center.addObserver(self, selector: #selector(QiscusChatVC.keyboardChange(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        
        self.hideKeyboardWhenTappedAround()
    }
    func showPhotoAccessAlert(){
        DispatchQueue.main.async(execute: {
            //let title = QiscusTextConfiguration.sharedInstance.galeryAccessAlertTitle
            let text = QiscusTextConfiguration.sharedInstance.galeryAccessAlertText
            let cancelTxt = QiscusTextConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusTextConfiguration.sharedInstance.alertSettingText
            QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: settingTxt, secondActionTitle: cancelTxt,
                doneAction: {
                    self.goToIPhoneSetting()
                },
                cancelAction: {}
            )
        })
    }
    func showCameraAccessAlert(){
        DispatchQueue.main.async(execute: {
            //let title = QiscusTextConfiguration.sharedInstance.galeryAccessAlertTitle
            let text = QiscusTextConfiguration.sharedInstance.galeryAccessAlertText
            let cancelTxt = QiscusTextConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusTextConfiguration.sharedInstance.alertSettingText
            QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: settingTxt, secondActionTitle: cancelTxt,
                doneAction: {
                    self.goToIPhoneSetting()
                },
                cancelAction: {}
            )
        })
    }
    func goToGaleryPicker(){
        DispatchQueue.main.async(execute: {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            picker.mediaTypes = [/*kUTTypeMovie as String,*/ kUTTypeImage as String]
            self.present(picker, animated: true, completion: nil)
        })
    }
    
    // MARK: - Keyboard Methode
    func keyboardWillHide(_ notification: Notification){
        let info: NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        let goToRow = self.lastVisibleRow
        
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.inputBarBottomMargin.constant = 0
            self.view.layoutIfNeeded()
            if goToRow != nil {
                self.scrollToIndexPath(goToRow!, position: .bottom, animated: true, delayed:  false)
            }
            }, completion: nil)
    }
    func keyboardChange(_ notification: Notification){
        let info:NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        
        let keyboardHeight: CGFloat = keyboardSize.height
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        
        let goToRow = self.lastVisibleRow
        
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.inputBarBottomMargin.constant = 0 - keyboardHeight
            self.view.layoutIfNeeded()
            if goToRow != nil {
                self.scrollToIndexPath(goToRow!, position: .bottom, animated: true, delayed:  false)
            }
            }, completion: nil)
        
    }
    
    // MARK: - ChatInputTextDelegate Delegate
    open func chatInputTextDidChange(chatInput input: ChatInputText, height: CGFloat) {
        self.minInputHeight.constant = height
        input.layoutIfNeeded()
    }
    open func valueChanged(value:String){
        if value == "" {
            sendButton.isEnabled = false
            sendButton.setBackgroundImage(self.sendOffImage, for: UIControlState())
        }else{
            sendButton.isEnabled = true
            sendButton.setBackgroundImage(self.sendOnImage, for: UIControlState())
        }
    }
    // MARK: - Table View DataSource
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return self.comment[section].count
    }
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let comment = self.comment[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        var cellPosition: CellPosition = CellPosition.left
        if comment.commentSenderEmail == QiscusConfig.sharedInstance.USER_EMAIL{
            cellPosition = CellPosition.right
        }
//        var first = false
        var last = false
        if (indexPath as NSIndexPath).row == (self.comment[(indexPath as NSIndexPath).section].count - 1){
            last = true
        }else{
            let commentAfter = self.comment[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row + 1]
            if (commentAfter.commentSenderEmail as String) != (comment.commentSenderEmail as String){
                last = true
            }
        }
//        if indexPath.row == 0 {
//            first = true
//        }else{
//            let commentBefore = self.comment[indexPath.section][indexPath.row - 1]
//            if (commentBefore.commentSenderEmail as String) != (comment.commentSenderEmail as String){
//                first = true
//            }
//        }
        if comment.commentType == QiscusCommentType.text {
            let tableCell = cell as! ChatCellText
            
            tableCell.setupCell(comment,last: last, position: cellPosition)
            //return cell
        }else{
            let file = QiscusFile.getCommentFile(comment.commentFileId)
            if file?.fileType == QFileType.media{
                let tableCell = cell as! ChatCellMedia
                tableCell.setupCell(comment, last: last, position: cellPosition)
                
                if file!.isLocalFileExist(){
                    tableCell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapMediaDisplay(_:)))
                    tableCell.tapRecognizer?.fileName = (file?.fileName)!
                    tableCell.tapRecognizer?.fileType = .media
                    tableCell.tapRecognizer?.fileURL = (file?.fileURL)!
                    tableCell.tapRecognizer?.fileLocalPath = (file?.fileLocalPath)!
                    tableCell.imageDisplay.addGestureRecognizer(tableCell.tapRecognizer!)
                }
            }else{
                let tableCell = cell as! ChatCellDocs
                tableCell.setupCell(comment, last: last, position: cellPosition)
                
                if !file!.isUploading{
                    tableCell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapChatFile(_:)))
                    tableCell.tapRecognizer?.fileURL = file!.fileURL
                    tableCell.tapRecognizer?.fileName = file!.fileName
                    tableCell.fileContainer.addGestureRecognizer(tableCell.tapRecognizer!)
                }
            }
        }
    }
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let comment = self.comment[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        
        if comment.commentType == QiscusCommentType.text {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cellText", for: indexPath) as! ChatCellText
            return cell
        }else{
            let file = QiscusFile.getCommentFile(comment.commentFileId)
            if file?.fileType == QFileType.media{
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellMedia", for: indexPath) as! ChatCellMedia
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellDocs", for: indexPath) as! ChatCellDocs
                return cell
            }
        }
        
    }
    open func numberOfSections(in tableView: UITableView) -> Int{
        return self.comment.count
    }
    
    // MARK: - TableView Delegate
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat{
        return 30
    }
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        var height:CGFloat = 50
        if self.comment.count > 0 {
            let comment = self.comment[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
            
            if comment.commentType == QiscusCommentType.text {
                height = ChatCellText.calculateRowHeightForComment(comment: comment)
            }else{
                let file = QiscusFile.getCommentFile(comment.commentFileId)
                
                if file?.fileType == QFileType.media {
                    height = 140
                }else{
                    height = 70
                }
            }
        }
        return height
    }
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?{
        let comment = self.comment[section][0]
        
        var date:String = ""
        
        if comment.commentDate == QiscusHelper.thisDateString {
            date = QiscusTextConfiguration.sharedInstance.todayText
        }else{
            date = comment.commentDate
        }

        let view = UIView(frame: CGRect(x: 0,y: 10,width: QiscusHelper.screenWidth(),height: 20))
        view.backgroundColor = UIColor.clear
        
        let dateLabel = UILabel()
        dateLabel.textAlignment = .center
        dateLabel.text = date
        dateLabel.font = UIFont.boldSystemFont(ofSize: 12)
        dateLabel.textColor = UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1)
        
        let textSize = dateLabel.sizeThatFits(CGSize(width: QiscusHelper.screenWidth(), height: 20))
        let textWidth = textSize.width + 30
        let textHeight = textSize.height + 6
        let cornerRadius:CGFloat = textHeight / 2
        let xPos = (QiscusHelper.screenWidth() - textWidth) / 2
        let dateFrame = CGRect(x: xPos, y: 10, width: textWidth, height: textHeight)
        dateLabel.frame = dateFrame
        dateLabel.layer.cornerRadius = cornerRadius
        dateLabel.clipsToBounds = true
        dateLabel.backgroundColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.7)
        dateLabel.textColor = UIColor.white
        view.addSubview(dateLabel)
        
        return view
    }
    
    func scrollToBottom(_ animated:Bool = false){
        if self.comment.count > 0{
            let section = self.comment.count - 1
            let row = self.comment[section].count - 1
            let bottomIndexPath = IndexPath(row: row, section: section)
            scrollToIndexPath(bottomIndexPath, position: .bottom, animated: animated)
        }
    }
    func scrollToIndexPath(_ indexPath:IndexPath, position: UITableViewScrollPosition, animated:Bool, delayed:Bool = true){
        
        if !delayed {
            self.tableView?.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: false)
        }else{
            let delay = 0.1 * Double(NSEC_PER_SEC)
            let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: time, execute: {
                if self.comment.count > 0 {
                self.tableView?.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom,
                    animated: false)
                }
            })
        }
    }
    // MARK: - Navigation Action
    func rightLeftButtonAction(_ sender: AnyObject) {
    }
    func righRightButtonAction(_ sender: AnyObject) {
    }
    func goBack() {
        self.isPresence = false
        if Qiscus.sharedInstance.isPushed {
            let _ = self.navigationController?.popViewController(animated: true)
        }else{
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
    }
    
    // MARK: - Load DataSource
    func loadData(){
        //TODO: - add progress
        //SJProgressHUD.showWaiting("Load Data ...", autoRemove: false)
        if(self.topicId > 0){
            self.comment = QiscusComment.groupAllCommentByDate(self.topicId,limit:20,firstLoad: true)
            
            if self.comment.count > 0 {
                print(self.topicId)
                print("comment found: \(self.comment.count)")
                self.tableView.reloadData()
                scrollToBottom()
                self.welcomeView.isHidden = true
                commentClient.syncMessage(self.topicId)
                //TODO: - dismiss progress
                //SJProgressHUD.dismiss()
            }else{
                self.welcomeView.isHidden = false
                commentClient.getListComment(topicId: self.topicId, commentId: 0, triggerDelegate: true, distincId: self.distincId)
            }
        }else{
            if self.users.count > 0 {
                loadWithUser = true
                commentClient.getListComment(withUsers: users, triggerDelegate: true, distincId: self.distincId, optionalDataCompletion: {optionalData
                    in
                    print("optional data from getListComment: \(optionalData)")
                })
            }
        }
    }
    func syncData(){
        if Qiscus.sharedInstance.connected{
        if self.topicId > 0 {
            if self.comment.count > 0 {
                commentClient.syncMessage(self.topicId)
            }else{
                if self.users.count > 0 {
                    //commentClient.getListComment(withUsers:users, triggerDelegate: true)
                }else{
                    commentClient.getListComment(topicId: self.topicId, commentId: 0, triggerDelegate: true)
                }
            }
        }
        }else{
            self.showNoConnectionToast()
        }
    }
    // MARK: - Qiscus Comment Delegate
    open func didSuccesPostComment(_ comment:QiscusComment){
        if comment.commentTopicId == self.topicId {
            let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
            let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
            DispatchQueue.main.async {
                self.comment[indexPathData.section][indexPathData.row] = comment
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
    }
    open func didFailedPostComment(_ comment:QiscusComment){
        if comment.commentTopicId == self.topicId {
            let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
            let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
            DispatchQueue.main.async {
                self.comment[indexPathData.section][indexPathData.row] = comment
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
        
    }
    open func downloadingMedia(_ comment:QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        if file.fileType == .media {
            let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
            if let cell = self.tableView.cellForRow(at: indexPath) as? ChatCellMedia{
                let downloadProgress:Int = Int(file.downloadProgress * 100)
                if file.downloadProgress > 0 {
                    cell.downloadButton.isHidden = true
                    cell.progressLabel.text = "\(downloadProgress) %"
                    cell.progressLabel.isHidden = false
                    cell.progressContainer.isHidden = false
                    cell.progressView.isHidden = false
                    
                    let newHeight = file.downloadProgress * cell.maxProgressHeight
                    cell.progressHeight.constant = newHeight
                    cell.progressView.layoutIfNeeded()
                }
            }
        }
    }
    open func didDownloadMedia(_ comment: QiscusComment){
        if Qiscus.sharedInstance.connected{
            let file = QiscusFile.getCommentFileWithComment(comment)!
            let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
            if file.fileType == .media {
                let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
                if let cell = self.tableView.cellForRow(at: indexPath) as? ChatCellMedia{
                    cell.downloadButton.isHidden = true
                    cell.progressLabel.isHidden = true
                    cell.imageDisplay.loadAsync("file://\(file.fileThumbPath)")
                   // cell.fileNameLabel.hidden = true
                    //cell.fileIcon.hidden = true
                    if cell.tapRecognizer != nil {
                        cell.imageDisplay.removeGestureRecognizer(cell.tapRecognizer!)
                    }
                    cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapMediaDisplay(_:)))
                    cell.tapRecognizer?.fileType = file.fileType
                    cell.tapRecognizer?.fileName = file.fileName
                    cell.tapRecognizer?.fileLocalPath = file.fileLocalPath
                    cell.tapRecognizer?.fileURL = file.fileURL
                    cell.progressContainer.isHidden = true
                    cell.progressView.isHidden = true
                    cell.imageDisplay.addGestureRecognizer(cell.tapRecognizer!)
                }
            }
        }else{
            self.showNoConnectionToast()
        }
    }
    open func didUploadFile(_ comment:QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        if file.fileType == .media {
            let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
            if let cell = self.tableView.cellForRow(at: indexPath) as? ChatCellMedia {
                cell.downloadButton.isHidden = true
                cell.progressLabel.isHidden = true
                cell.progressContainer.isHidden = true
                cell.progressView.isHidden = true
                //cell.mediaDisplay.loadAsync("file://\(file.fileThumbPath)")
                //cell.fileNameLabel.hidden = true
                //cell.fileIcon.hidden = true
                if cell.tapRecognizer != nil {
                    cell.imageDisplay.removeGestureRecognizer(cell.tapRecognizer!)
                }
                cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapMediaDisplay(_:)))
                cell.tapRecognizer?.fileType = file.fileType
                cell.tapRecognizer?.fileName = file.fileName
                cell.tapRecognizer?.fileLocalPath = file.fileLocalPath
                cell.tapRecognizer?.fileURL = file.fileURL
                cell.imageDisplay.addGestureRecognizer(cell.tapRecognizer!)
            }
        }else{
            let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
            if let cell = self.tableView.cellForRow(at: indexPath) as? ChatCellDocs {
                if cell.tapRecognizer != nil {
                    cell.fileContainer.removeGestureRecognizer(cell.tapRecognizer!)
                }
                cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapChatFile(_:)))
                cell.tapRecognizer?.fileURL = file.fileURL
                
                cell.fileContainer.addGestureRecognizer(cell.tapRecognizer!)
            }
        }
    }
    open func uploadingFile(_ comment:QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
        if file.fileType == .media {
            if let cell = self.tableView.cellForRow(at: indexPath) as? ChatCellMedia {
                let downloadProgress:Int = Int(file.uploadProgress * 100)
                if file.uploadProgress > 0 {
                    cell.downloadButton.isHidden = true
                    cell.progressLabel.text = "\(downloadProgress) %"
                    cell.progressLabel.isHidden = false
                    cell.progressContainer.isHidden = false
                    cell.progressView.isHidden = false
                    
                    let newHeight = file.uploadProgress * cell.maxProgressHeight
                    cell.progressHeight.constant = newHeight
                    cell.progressView.layoutIfNeeded()
                }
            }
        }else{
            if let cell = self.tableView.cellForRow(at: indexPath) as? ChatCellDocs {
                if file.uploadProgress > 0 {
                    let uploadProgres = Int(file.uploadProgress * 100)
                    let uploading = QiscusTextConfiguration.sharedInstance.uploadingText
                    
                    cell.dateLabel.text = "\(uploading) \(ChatCellDocs.getFormattedStringFromInt(uploadProgres)) %"
                }
            }
        }
    }
    open func didFailedUploadFile(_ comment:QiscusComment){
        
    }
    open func didSuccessPostFile(_ comment:QiscusComment){
        
    }
    open func didFailedPostFile(_ comment:QiscusComment){
        
    }
    open func didFinishLoadMore(){
        self.loadMoreControl.endRefreshing()
    }
    open func finishedLoadFromAPI(_ topicId: Int){
        //TODO: - dismiss progress
        //SJProgressHUD.dismiss()
        if self.comment.count == 0 && loadWithUser{
            loadWithUser = false
            self.loadData()
        }
    }
    open func didFailedLoadDataFromAPI(_ error: String){
        //TODO: - dismiss progress
        //SJProgressHUD.dismiss()
    }
    open func gotNewComment(_ comments:[QiscusComment]){
        var refresh = false
        if self.comment.count == 0 {
            refresh = true
        }
        
//        var indexPaths = [NSIndexPath]()
//        var indexSets = [NSIndexSet]()
        var needScroolToBottom = false
        //update data first
        
        if firstLoad{
            needScroolToBottom = true
            firstLoad = false
            refresh = true
        }
        if isLastRowVisible && !needScroolToBottom{
            needScroolToBottom = true
        }
        if comments.count == 1 && !needScroolToBottom{
            let firstComment = comments[0]
            if firstComment.commentSenderEmail == QiscusConfig.sharedInstance.USER_EMAIL{
                needScroolToBottom = true
            }
        }
        //var indexPathToReload = [NSIndexPath]()
        self.welcomeView.isHidden = true
        
        for singleComment in comments{
            if singleComment.commentTopicId == self.topicId {
                let indexPathData = QiscusHelper.properIndexPathOf(comment: singleComment, inGroupedComment: self.comment)
                
                let indexPath = IndexPath(row: indexPathData.row, section: indexPathData.section)
                let indexSet = IndexSet(integer: indexPathData.section)
                
                
                if indexPathData.newGroup {
                    var newCommentGroup = [QiscusComment]()
                    newCommentGroup.append(singleComment)
                    self.comment.insert(newCommentGroup, at: indexPathData.section)
                    self.tableView.beginUpdates()
                    self.tableView.insertSections(indexSet, with: .top)
                    self.tableView.insertRows(at: [indexPath], with: .top)
                    self.tableView.endUpdates()
//                    indexSets.append(indexSet)
//                    indexPaths.append(indexPath)
                }else{
                    self.comment[indexPathData.section].insert(singleComment, at: indexPathData.row)
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [indexPath], with: .top)
                    self.tableView.endUpdates()
                    //indexPaths.append(indexPath)
                }
                
                if (indexPath as NSIndexPath).row > 0 {
                    let reloadIndexPath = IndexPath(row: (indexPath as NSIndexPath).row - 1, section: (indexPath as NSIndexPath).section)
                    self.tableView.reloadRows(at: [reloadIndexPath], with: .none)
                }
            }
        }
        
        
        if !refresh {
//            self.tableView.beginUpdates()
//            var indexPathToReload = [NSIndexPath]()
//            for indexSet in indexSets{
//                self.tableView.insertSections(indexSet, withRowAnimation: .Top)
//            }
//            self.tableView.endUpdates()
//            self.tableView.beginUpdates()
//            for indexPath in indexPaths {
//                self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Top)
//                if indexPath.row > 0 {
//                    let newindexPath = NSIndexPath(forRow: indexPath.row - 1, inSection: indexPath.section)
//                    indexPathToReload.append(newindexPath)
//                }
//            }
//            self.tableView.endUpdates()
//            if indexPathToReload.count > 0 {
//                self.tableView.reloadRowsAtIndexPaths(indexPathToReload, withRowAnimation: .None)
//            }
        }else{
            self.tableView.reloadData()
        }
        if needScroolToBottom{
            scrollToBottom()
        }
    }
    
    // MARK: - Button Action
    open func showLoading(_ text:String = "Loading"){
        //TODO: - add progress
        //SJProgressHUD.showWaiting("text", autoRemove: false)
    }
    open func dismissLoading(){
        //TODO: - dismiss progress
        //SJProgressHUD.dismiss()
    }
    func unlockChat(){
        UIView.animate(withDuration: 0.6, animations: {
            self.archievedNotifTop.constant = 65
            self.archievedNotifView.layoutIfNeeded()
            }, completion: { _ in
                self.archievedNotifView.isHidden = true
        })
    }
    func lockChat(){
        self.archievedNotifTop.constant = 65
        self.archievedNotifView.isHidden = false
        UIView.animate(withDuration: 0.6, animations: {
            self.archievedNotifTop.constant = 0
            self.archievedNotifView.layoutIfNeeded()
            }
        )
    }
    func confirmUnlockChat(){
        self.unlockAction()
    }
    func sendMessage(){
        if Qiscus.sharedInstance.connected{
            commentClient.postMessage(message: inputText.value, topicId: self.topicId)
            inputText.clearValue()
            inputText.text = ""
            sendButton.isEnabled = false
            self.scrollToBottom()
            self.minInputHeight.constant = 25
            self.inputText.layoutIfNeeded()
        }else{
            self.showNoConnectionToast()
        }
    }
    func tapMediaDisplay(_ sender: ChatTapRecognizer){
        if let delegate = self.cellDelegate{
            delegate.didTapMediaCell(URL(string: "file://\(sender.fileLocalPath)")!, mediaName: sender.fileName)
        }else{
            print("mediaIndex: \(sender.mediaIndex)")
            var currentIndex = 0
            //TODO: - imageProvider
            //self.imageProvider.images = [UIImage]()
            self.galleryItems = [UIImage]()
            var i = 0
            for groupComment in self.comment{
                for singleComment in groupComment {
                    if singleComment.commentType != QiscusCommentType.text {
                        let file = QiscusFile.getCommentFile(singleComment.commentFileId)
                        if file?.fileType == QFileType.media{
                            if file!.isLocalFileExist(){
                                if file?.fileLocalPath == sender.fileLocalPath{
                                    currentIndex = i
                                    
                                }
                                i += 1
                                let urlString = "file://\((file?.fileLocalPath)!)"
                                if let url = URL(string: urlString) {
                                    if let data = try? Data(contentsOf: url) {
                                        let image = UIImage(data: data)!
                                        if file?.fileLocalPath == sender.fileLocalPath{
                                            self.selectedImage = image
                                        }
                                        //TODO: - imageProvider
                                        self.galleryItems.append(image)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            //let galleryItems = GalleryItemsDatasource
            
//            let closeButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 50, height: 50)))
//            closeButton.setImage(UIImage(named: "close_normal"), forState: UIControlState.Normal)
//            closeButton.setImage(UIImage(named: "close_highlighted"), forState: UIControlState.Highlighted)
            //let closeButtonConfig = GalleryConfigurationItem.CloseButton(closeButton)
            
            let closeButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
            closeButton.setImage(Qiscus.image(named: "close")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            closeButton.tintColor = UIColor.white
            closeButton.imageView?.contentMode = .scaleAspectFit
            
            let seeAllButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
            seeAllButton.setTitle("", for: UIControlState())
            seeAllButton.setImage(Qiscus.image(named: "viewmode")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            seeAllButton.tintColor = UIColor.white
            seeAllButton.imageView?.contentMode = .scaleAspectFit
            
//            let saveButton = UIButton(frame: CGRectMake(QiscusHelper.screenWidth() - 65, -17, 20, 20))
//            saveButton.setTitle("", forState: .Normal)
//            saveButton.setImage(Qiscus.image(named: "ic_download-1")?.imageWithRenderingMode(.AlwaysTemplate), forState: .Normal)
//            saveButton.tintColor = UIColor.whiteColor()
//            saveButton.addTarget(self, action: #selector(QiscusChatVC.saveImageToGalery), forControlEvents: .TouchUpInside)
            
      //      self.imagePreview = GalleryViewController(imageProvider: imageProvider, displacedView: sender.view!, imageCount: self.imageProvider.imageCount, startIndex: currentIndex, configuration: [GalleryConfigurationItem.SeeAllButton(seeAllButton),GalleryConfigurationItem.CloseButton(closeButton)])
            
//            let headerView = UIView(frame: CGRectMake(0, 0, QiscusHelper.screenWidth(),30))
//            headerView.addSubview(saveButton)
//            //headerView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
//            self.imagePreview?.headerView = headerView
            
            //self.presentImageGallery(self.imagePreview!)
            let gallery = GalleryViewController(startIndex: currentIndex, itemsDatasource: self, displacedViewsDatasource: nil, configuration: self.galleryConfiguration())
            self.presentImageGallery(gallery)
        }
    }
    func tapChatFile(_ sender: ChatTapRecognizer){
        let url = sender.fileURL
        let fileName = sender.fileName
        
        let preview = ChatPreviewDocVC()
        preview.fileName = fileName
        preview.url = url
        preview.roomName = QiscusTextConfiguration.sharedInstance.chatTitle
        self.navigationController?.pushViewController(preview, animated: true)
    }
    func uploadImage(){
        if Qiscus.sharedInstance.connected{
            let photoPermissions = PHPhotoLibrary.authorizationStatus()
            
            if(photoPermissions == PHAuthorizationStatus.authorized){
                self.goToGaleryPicker()
            }else if(photoPermissions == PHAuthorizationStatus.notDetermined){
                PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                    switch status{
                    case .authorized:
                        self.goToGaleryPicker()
                        break
                    case .denied:
                        self.showPhotoAccessAlert()
                        break
                    default:
                        self.showPhotoAccessAlert()
                        break
                    }
                })
            }else{
                self.showPhotoAccessAlert()
            }
        }else{
            self.showNoConnectionToast()
        }
    }
    func uploadFromCamera(){
        if Qiscus.sharedInstance.connected{
            if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) ==  AVAuthorizationStatus.authorized
            {
                DispatchQueue.main.async(execute: {
                    let picker = UIImagePickerController()
                    picker.delegate = self
                    picker.allowsEditing = false
                    picker.mediaTypes = [(kUTTypeImage as String)]
                    
                    picker.sourceType = UIImagePickerControllerSourceType.camera
                    self.present(picker, animated: true, completion: nil)
                })
            }else{
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                    DispatchQueue.main.async(execute: {
                        self.showCameraAccessAlert()
                    })
                })
            }
        }else{
            self.showNoConnectionToast()
        }
    }
    func iCloudOpen(){
        if Qiscus.sharedInstance.connected{
            let documentPicker = UIDocumentPickerViewController(documentTypes: self.UTIs, in: UIDocumentPickerMode.import)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
    //        documentPicker.navigationController?.navigationBar.verticalGradientColor(QiscusUIConfiguration.sharedInstance.baseColor, bottomColor: QiscusUIConfiguration.sharedInstance.gradientColor)
            self.present(documentPicker, animated: true, completion: nil)
        }else{
            self.showNoConnectionToast()
        }
    }
    open func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        //TODO: - add progress
        //SJProgressHUD.showWaiting("Processing File", autoRemove: false)
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: NSFileCoordinator.ReadingOptions.forUploading, error: nil) { (dataURL) in
            do{
                let data:Data = try Data(contentsOf: dataURL, options: NSData.ReadingOptions.mappedIfSafe)
                var fileName = dataURL.lastPathComponent.replacingOccurrences(of: "%20", with: "_")
                fileName = fileName.replacingOccurrences(of: " ", with: "_")
                
                let fileNameArr = (fileName as String).characters.split(separator: ".")
                let ext = String(fileNameArr.last!).lowercased()
                
                // get file extension
                let isGifImage:Bool = (ext == "gif" || ext == "gif_")
                let isJPEGImage:Bool = (ext == "jpg" || ext == "jpg_")
                let isPNGImage:Bool = (ext == "png" || ext == "png_")
                //let isVideo:Bool = (ext == "mp4" || ext == "mp4_" || ext == "mov" || ext == "mov_")
                
                if isGifImage || isPNGImage || isJPEGImage{
                    var imagePath:URL?
                    let image = UIImage(data: data)
                    if isGifImage{
                        imagePath = dataURL
                    }
                    //TODO: - dismiss progress
                    //SJProgressHUD.dismiss()
                    //let title = QiscusTextConfiguration.sharedInstance.confirmationTitle
                    let text = QiscusTextConfiguration.sharedInstance.confirmationImageUploadText
                    let okText = QiscusTextConfiguration.sharedInstance.alertOkText
                    let cancelText = QiscusTextConfiguration.sharedInstance.alertCancelText
                    QPopUpView.showAlert(withTarget: self, image: image, message: text, firstActionTitle: okText, secondActionTitle: cancelText,
                        doneAction: {
                            self.continueImageUpload(image, imageName: fileName, imagePath: imagePath)
                        },
                        cancelAction: {}
                    )
                }else{
                    //TODO: - dismiss progress
                    //SJProgressHUD.dismiss()
                    //let title = QiscusTextConfiguration.sharedInstance.confirmationTitle
                    let textFirst = QiscusTextConfiguration.sharedInstance.confirmationFileUploadText
                    let textMiddle = "\(fileName as String)"
                    let textLast = QiscusTextConfiguration.sharedInstance.questionMark
                    let text = "\(textFirst) \(textMiddle) \(textLast)"
                    let okText = QiscusTextConfiguration.sharedInstance.alertOkText
                    let cancelText = QiscusTextConfiguration.sharedInstance.alertCancelText
                    QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: okText, secondActionTitle: cancelText,
                        doneAction: {
                            self.continueImageUpload(imageName: fileName, imagePath: dataURL, imageNSData: data)
                        },
                        cancelAction: {
                        }
                    )
                }
            }catch _{
                //TODO: - dismiss progress
                //SJProgressHUD.dismiss()
            }
        }
    }
    func goToIPhoneSetting(){
        UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Upload Action
    func continueImageUpload(_ image:UIImage? = nil,imageName:String,imagePath:URL? = nil, imageNSData:Data? = nil){
        if Qiscus.sharedInstance.connected{
            print("come here")
            commentClient.uploadImage(self.topicId, image: image, imageName: imageName, imagePath: imagePath, imageNSData: imageNSData)
        }else{
            self.showNoConnectionToast()
        }
    }
    
    // MARK: UIImagePicker Delegate
    open func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let fileType:String = info[UIImagePickerControllerMediaType] as! String
        picker.dismiss(animated: true, completion: nil)
        
        if fileType == "public.image"{
            var imageName:String = ""
            var image = UIImage()
            var imagePath:URL?
            if let imageURL = info[UIImagePickerControllerReferenceURL] as? URL{
                imageName = imageURL.lastPathComponent
                image = info[UIImagePickerControllerOriginalImage] as! UIImage
                
                let imageNameArr = imageName.characters.split(separator: ".")
                let imageExt:String = String(imageNameArr.last!).lowercased()
                
                if imageExt.isEqual("gif") || imageExt.isEqual("gif_"){
                    imagePath = imageURL
                }
            }else{
                imageName = "\(timeToken).jpg"
                image = info[UIImagePickerControllerOriginalImage] as! UIImage
            }
            //let title = QiscusTextConfiguration.sharedInstance.confirmationTitle
            let text = QiscusTextConfiguration.sharedInstance.confirmationImageUploadText
            let okText = QiscusTextConfiguration.sharedInstance.alertOkText
            let cancelText = QiscusTextConfiguration.sharedInstance.alertCancelText
            
            QPopUpView.showAlert(withTarget: self, image: image, message: text, firstActionTitle: okText, secondActionTitle: cancelText,
                doneAction: {
                    self.continueImageUpload(image, imageName: imageName, imagePath: imagePath)
                },
                cancelAction: {}
            )
        }
    }
    open func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Load More Control
    func loadMore(){
        if self.comment.count > 0 {
            if Qiscus.sharedInstance.connected{
                let firstComment = self.comment[0][0]
                
                if firstComment.commentBeforeId > 0 {
                    commentClient.loadMoreComment(fromCommentId: firstComment.commentId, topicId: self.topicId, limit: 10)
                }else{
                    self.loadMoreControl.endRefreshing()
                    self.loadMoreControl.isEnabled = false
                }
            }else{
                self.showNoConnectionToast()
                self.loadMoreControl.endRefreshing()
            }
        }else{
            self.loadData()
        }
    }
    
    // MARK: - Back Button
    class func backButton(_ target: UIViewController, action: Selector) -> UIBarButtonItem{
        let backIcon = UIImageView()
        backIcon.contentMode = .scaleAspectFit
        
        let backLabel = UILabel()
        
        backLabel.text = QiscusTextConfiguration.sharedInstance.backText
        backLabel.textColor = UIColor.white
        backLabel.font = UIFont.systemFont(ofSize: 12)
        
        let image = UIImage(named: "ic_back", in: Qiscus.bundle, compatibleWith: nil)?.localizedImage()
        backIcon.image = image
        
        
        if UIApplication.shared.userInterfaceLayoutDirection == .leftToRight {
            backIcon.frame = CGRect(x: 0,y: 0,width: 10,height: 15)
            backLabel.frame = CGRect(x: 15,y: 0,width: 45,height: 15)
        }else{
            backIcon.frame = CGRect(x: 50,y: 0,width: 10,height: 15)
            backLabel.frame = CGRect(x: 0,y: 0,width: 45,height: 15)
        }
        
        
        let backButton = UIButton(frame:CGRect(x: 0,y: 0,width: 60,height: 20))
        backButton.addSubview(backIcon)
        backButton.addSubview(backLabel)
        backButton.addTarget(target, action: action, for: UIControlEvents.touchUpInside)
        
        return UIBarButtonItem(customView: backButton)
    }
    
    func showAlert(alert:UIAlertController){
        self.present(alert, animated: true, completion: nil)
    }
    
    func setGradientChatNavigation(withTopColor topColor:UIColor, bottomColor:UIColor, tintColor:UIColor){
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.tintColor = tintColor
        if !Qiscus.sharedInstance.isPushed{
            self.navigationController?.navigationBar.verticalGradientColor(self.topColor, bottomColor: self.bottomColor)
            self.navigationController?.navigationBar.tintColor = self.tintColor
        }
    }
    func setNavigationColor(_ color:UIColor, tintColor:UIColor){
        self.topColor = color
        self.bottomColor = color
        self.tintColor = tintColor
        if !Qiscus.sharedInstance.isPushed{
            self.navigationController?.navigationBar.verticalGradientColor(topColor, bottomColor: bottomColor)
            self.navigationController?.navigationBar.tintColor = tintColor
        }
    }
    func showNoConnectionToast(){
        QToasterSwift.toast(target: self, text: QiscusTextConfiguration.sharedInstance.noConnectionText, backgroundColor: UIColor(red: 0.9, green: 0,blue: 0,alpha: 0.8), textColor: UIColor.white)
    }
    
    // MARK: - Galery Function
    public func galleryConfiguration()-> GalleryConfiguration{
        let closeButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
        closeButton.setImage(Qiscus.image(named: "close")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        closeButton.tintColor = UIColor.white
        closeButton.imageView?.contentMode = .scaleAspectFit
        
        let seeAllButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
        seeAllButton.setTitle("", for: UIControlState())
        seeAllButton.setImage(Qiscus.image(named: "viewmode")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        seeAllButton.tintColor = UIColor.white
        seeAllButton.imageView?.contentMode = .scaleAspectFit
        
        return [
            GalleryConfigurationItem.closeButtonMode(.custom(closeButton)),
            GalleryConfigurationItem.thumbnailsButtonMode(.custom(seeAllButton))
        ]
    }
    public func itemCount() -> Int {
        return self.galleryItems.count
    }
    public func provideGalleryItem(_ index: Int) -> GalleryItem {
        let image = self.galleryItems[index]
        
        return GalleryItem.image { $0(image) }
    }
    func saveImageToGalery(){
        print("saving image")
        UIImageWriteToSavedPhotosAlbum(self.selectedImage, self, #selector(QiscusChatVC.succesSaveImage), nil)
    }
    func succesSaveImage(){
         QToasterSwift.toast(target: self.imagePreview!, text: "Successfully save image to your galery", backgroundColor: UIColor(red: 0, green: 0.8,blue: 0,alpha: 0.8), textColor: UIColor.white)
    }
}
