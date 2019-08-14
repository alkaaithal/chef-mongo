include_recipe "starter::repo"
node['test']['packages'].each do |pkg|
 package pkg['name'] do
   version pkg['version']
   action :install
 end
end
