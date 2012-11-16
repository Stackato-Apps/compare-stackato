#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojolicious::Static;
use Mojo::UserAgent;
use Mojo::Util;
use JSON::XS;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $static = Mojolicious::Static->new;
push @{$static->paths}, 'css';

get '/' => sub {
  my $self = shift;
  $self->render('compare');
};

post '/endpoint-details' => sub {
  my $self = shift;
  
  my $s_info_endpoint = "api.stacka.to/info";
  my $s_services_endpoint = "api.stacka.to/info/services";
  
  my $api_endpoint = $self->param('api_endpoint');
  if ($api_endpoint !~ /^((https?|ftp):\/\/)?(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&amp;'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&amp;'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&amp;'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&amp;'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&amp;'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i ) {
    $self->render('endpoint-failure', api_endpoint => $api_endpoint);
  }
  else {
    my $api_info_endpoint = $api_endpoint . '/info';
    my $api_services_endpoint = $api_endpoint . '/info/services';
    $api_info_endpoint =~ s|//|/|g;
    $api_services_endpoint =~ s|//|/|g;
    my $ua = Mojo::UserAgent->new;
    
    my $paasNames = {
        'api.cloudfoundry.com' => 'Cloud Foundry',
        'api.appfog.com' => 'AppFog',
        'api.ironfoundry.me' => 'Iron Foundry',
        'api.uhurucloud.com' => 'Uhuru AppCloud'
    };
    my $paas_name = $paasNames->{$api_endpoint} || $api_endpoint;
    
    my $frameworks = $ua->get($api_info_endpoint)->res->json('/frameworks');
    if (!$frameworks) {
      $self->render('endpoint-failure', paas_name => $paas_name, api_endpoint => $api_endpoint);
    }
    else {
      my @framework_names = sort(keys $frameworks);
      my $s_frameworks = $ua->get($s_info_endpoint)->res->json('/frameworks');
      my @s_framework_names = sort(keys $s_frameworks);
      
      my %runtime_data = extract_runtime_data($api_info_endpoint);
      my %s_runtime_data = extract_runtime_data($s_info_endpoint);
      
      my %service_data = extract_service_data($api_services_endpoint);
      my %s_service_data = extract_service_data($s_services_endpoint);
    
      $self->render('endpoint-details', paas_name => $paas_name, api_endpoint => $api_endpoint,
                    frameworks => \@framework_names, runtimes => \%runtime_data, services => \%service_data,
                    s_frameworks => \@s_framework_names, s_runtimes => \%s_runtime_data, s_services => \%s_service_data);
    }
  }
};

sub extract_runtime_data {
  my $api_endpoint = shift;
  my $ua = Mojo::UserAgent->new;
  my $frameworks = $ua->get($api_endpoint)->res->json('/frameworks');
  my %runtime_data;
  
  foreach my $fw ( sort(keys $frameworks) ) {
    foreach my $runtime (@{$frameworks->{$fw}->{'runtimes'}}) {
      $runtime_data{$runtime->{'name'}} = {'description'=> $runtime->{'description'}, 'version' => $runtime->{'version'}};
    }
  }
  return %runtime_data;
}

sub extract_service_data {
  my $api_endpoint = shift;
  my $ua = Mojo::UserAgent->new;
  my $services = $ua->get($api_endpoint)->res->json;
  my %service_data;
  
  foreach my $service_type ( sort(keys $services)) {
    foreach my $service ( sort(keys $services->{$service_type}) ) {
      $service_data{$service} = $services->{$service_type}->{$service};
    }
  }
  
  return %service_data;
}


app->start;