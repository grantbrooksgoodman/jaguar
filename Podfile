# Uncomment the next line to define a global platform for your project
platform :ios, '15.5'

pod 'GoogleUtilities'

def google_utilites
  # pod 'GoogleUtilities/AppDelegateSwizzler'
  # pod 'GoogleUtilities/Environment'
  # pod 'GoogleUtilities/ISASwizzler'
  # pod 'GoogleUtilities/Logger'
  # pod 'GoogleUtilities/MethodSwizzler'
  # pod 'GoogleUtilities/NSData+zlib'
  # pod 'GoogleUtilities/Network'
  # pod 'GoogleUtilities/Reachability'
  # pod 'GoogleUtilities/UserDefaults'
  # pod 'GTMSessionFetcher'
end

def shared_dependencies
    pod 'Firebase/Auth'
    pod 'Firebase/Database'
    pod 'Firebase/Messaging'
    pod 'Firebase/Storage' 
    pod 'MessageKit'
    pod 'PhoneNumberKit', '~> 3.1'
end

def app_dependencies
  pod 'Firebase/Analytics'
  pod 'PKHUD', '~> 5.0'
  pod 'ProgressHUD'
end

target 'Jaguar' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  inhibit_all_warnings!

  # Pods for Application
    google_utilites
    shared_dependencies
    app_dependencies

    target 'JaguarTests' do
        inherit! :search_paths
    end
end

target 'NotificationService' do
  use_frameworks!
  inhibit_all_warnings!
  
  #inherit! :search_paths
  shared_dependencies
end
