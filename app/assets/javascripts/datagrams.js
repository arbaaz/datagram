//= require angular-pusher
//= require 'checklist-model.js'
//= require highlight.pack.js
//= require angular-highlightjs.js
//= require directives.js
var datagramsApp = angular.module('datagramsApp', ['restangular','ui.router','checklist-model', 'hljs', 'doowb.angular-pusher', 'directives.json','ui.bootstrap', "pascalprecht.translate", "humanSeconds","ngMaterial","ui.ace","md.data.table","mgo-angular-wizard","highcharts-ng","ngSanitize"]).
config(['PusherServiceProvider',
  function(PusherServiceProvider) {
    PusherServiceProvider
      .setToken('ab5d78a0ff96a4179917')
      .setOptions({});
  }
       ]).config(['$mdThemingProvider',function($mdThemingProvider) {
  $mdThemingProvider.setDefaultTheme('amber');
}]);;

angular.module('datagramsApp').filter('fromNow', function() {
  return function(date) {
    return moment(date).fromNow();
  };
});


datagramsApp.config(function($stateProvider,$urlRouterProvider) {
  $urlRouterProvider.otherwise('/');

  $stateProvider.
    state('index',
	  {url: '/', templateUrl: "index.html"}
	 ).
    state('new',
	  {
	    url: '/new',
	    templateUrl: 'new.html'
	  }).
    state('show',
	  {
	    url: '/:id',
	    templateUrl: 'show.html'
	  }).
    state('edit',
	  {
	    url: '/:id/edit',
	    templateUrl: 'edit.html'
	  });

});

angular.module('datagramsApp').controller('datagramsCtrl',['$scope','Restangular','$stateParams','$timeout', function($scope, Restangular,$stateParams, $timeout) {
  var load = function() {
    $('#loading').show();
    Restangular.all('api/v1/datagrams').getList().then(function(r) {
      console.log(r);
      $scope.datagrams = _.sortBy(r, function(s) { return s.name});
      $('#loading').hide();
      $timeout(load, 60000);

    });
  };
  load();


}]);

angular.module('datagramsApp').controller('newDatagramCtrl',['$scope','Restangular','$stateParams', '$state', function($scope, Restangular, $stateParams, $state) {
  Restangular.all('api/v1/watches').getList().then(function(r) {
    $scope.watches = r;
  });
  Restangular.one('api/v1/datagrams/new').get().then(function(r) {
    $scope.datagram = r;
  });
  Restangular.all('api/v1/sources').getList().then(function(r) {
    $scope.sources = r;
  });

  var baseDatagrams = Restangular.all('api/v1/datagrams');
  var loaded = false;
  $scope.save = function() {
    baseDatagrams.post({datagram: $scope.datagram}).then(function(r) {
      $state.go('show',{id: r.id});
    });
  };
  $scope.selectedWatches = [];
  $scope.onSelect = function(a) {
    $scope.datagram.watch_ids = _.map($scope.selectedWatches, function(w) { return w.id;});
    console.log($scope.datagram.watch_ids);
    var ps = _.map($scope.selectedWatches,function(w) { return w.params});
    console.log(ps);
    $scope.datagram.publish_params = _.reduce(ps, function(sum, n) {
      console.log('n',n);
      console.log('sum',sum);
      if (!sum) { sum = {}};
      return _.merge(sum,n);
    });

  };

}]);

angular.module('datagramsApp').controller('datagramCtrl',['$scope','Restangular','$stateParams', '$state', 'Pusher', '$http', '$sce', function($scope, Restangular, $stateParams, $state, Pusher, $http, $sce) {

  $scope.getDatagram = function(id, params) {
    Restangular.one('api/v1/datagrams',id, params).get().then(function(r) {
      $scope.datagram = r;
      $scope.views = ($scope.datagram.views || []);
      _.map($scope.views, function(v) {$scope.render(v)});
    });
  };

  $scope.archive = function() {
    console.log($scope.datagram);
    $http({method: 'PATCH', url: 'api/v1/datagrams/' + $scope.datagram.id, data:{ datagram: {archived: true}}}).then(function(r) {
      console.log('saved datagram');
      $state.go('index');
    });
  };


    var subscribed = false;

  $scope.refresh = function() {
    $scope.loading = true;
    $scope.datagram.customPUT({id:$scope.datagram.id, params: $scope.datagram.publish_params}, 'refresh' ).then(function(r) {
      console.log(r);
      if(true) {
	console.log('subscribing to ' + r.channel);
	Pusher.subscribe(r.channel,'data', function(item) {
	      console.log('Pusher received', item);
	      subscribed = true;
	  $scope.getDatagram($scope.datagram.id, {params: $scope.datagram.publish_params});
	  $scope.loading = false;
	  });
      };
    });
  };


  var refreshWatchResponses = function() {
    _.each($scope.datagram.watches, function(w,i) {
      console.log('subscribing to ', w.token);

    });
  };

  if ($stateParams.id) {
    $scope.getDatagram($stateParams.id);
  };

  $scope.addTab = function() {
    $scope.views.push({name: 'Foo', type: 'jq', template:null});
  };

  $scope.renderedData = {};
  $scope.render = function(view) {
    console.log($scope.datagram)
    if (view.type === 'json' || view.type === 'chart') {
      $scope.renderedData[view.name] = jmespath.search($scope.datagram,view.template);
    } else if (view.type === 'mustache') {
      $scope.renderedData[view.name] = Mustache.render(view.template, $scope.datagram)
    } else if (view.type === 'liquid') {
      var tmpl = Liquid.parse(view.template);
      $scope.renderedData[view.name] = $sce.trustAsHtml(tmpl.render($scope.datagram));
    }
    console.log($scope.renderedData[view.name]);
  };

  $scope.update = function() {
    $scope.updating = true;
    $scope.datagram.views = $scope.views;
    console.log($scope.datagram);
    $http({method: 'PATCH', url: 'api/v1/datagrams/' + $scope.datagram.id, data:{ datagram: $scope.datagram}}).then(function(r) {
      console.log('saved datagram');
      $scope.updating = false;

    });

  };

}]);

angular.module('datagramsApp').controller('editDatagramCtrl',['$scope','$http','$stateParams', '$state', 'Pusher', function($scope, $http, $stateParams, $state, Pusher) {
  var loaded = false;
    $scope.getDatagram = function(id) {
      $http.get('api/v1/datagrams/' + id).then(function(r) {
	console.log(r);
	$scope.datagram = r.data;
    });
  };

  $scope.aceLoaded = function(_editor) {
    // Options
    _editor.setHighlightActiveLine(false);
  };

  if ($stateParams.id) {
    $scope.getDatagram($stateParams.id);
  };
  $http.get('api/v1/watches').then(function(r) {
    $scope.watches = r.data;
  });


  $scope.save = function() {
    console.log($scope.datagram);
    $http({method: 'PATCH', url: 'api/v1/datagrams/' + $scope.datagram.id, data:{ datagram: $scope.datagram}}).then(function(r) {
      console.log('saved datagram');
      $state.go('show',{id: $scope.datagram.id});
    });
  };

}]);
