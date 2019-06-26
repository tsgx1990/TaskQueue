#
#  Be sure to run `pod spec lint YLTaskQueue.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "YLTaskQueue"
  spec.version      = "0.0.1"
  spec.summary      = "Task queue"
  spec.description  = <<-DESC
  	Task queue to manage serial and parallel tasks
                   DESC
  spec.homepage     = "https://dabao.netlify.com/"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "guanglong" => "dabaotthao@163.com" }
  spec.platform     = :ios, "8.0"
  spec.source       = { :git => "https://github.com/tsgx1990/TaskQueue.git" }
  spec.source_files = "TaskQueue/**/*.{h,m}"
  spec.requires_arc = true

end
