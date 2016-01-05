Pod::Spec.new do |s|
  s.name = 'Horreum'
  s.version = '0.1'
  s.license = 'MIT'
  s.summary = 'Private - Main - Child | Core Data Stack'
  s.homepage = 'https://github.com/gekitz/Horreum'
  s.authors = { 'Georg Kitz' => 'georgkitz@gmail.com' }
  s.source = { :git => 'https://github.com/gekitz/Horreum.git', :tag => s.version }
  s.ios.deployment_target = '9.0'
  s.source_files = 'Horreum/Classes/*.swift'
  s.framework = 'CoreData'
  s.requires_arc = true
end
