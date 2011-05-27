@visitsHash = {}
unlinked = {}
@MAX = 2147483647
#Utils

  
#Site
class Site
  constructor: (hItem, @nodeName)->
    @id = hItem.id
    @items = [hItem]
    @visitsArr = []
    @linked = false
  
  hasLink: ()->
    @linked = true
  
  addItem: (item)->
    @items.push(item)
    
  updateVisits: (callback)->
    @items.forEach (item, i)=>
      chrome.history.getVisits url: item.url, (visits)=> 
        visits.forEach _.bind(@addVisit, this)
        callback() if i == @items.length - 1
      
  addVisit: (visit)->
    visitsHash[visit.visitId] = this
    @visitsArr.push visit

  getPageViews: ()-> @items.length
  
  getVisits: ()-> @visitsArr
  
  visualize: ()->
    return @daysByYr if @daysByYr? 
    @daysByYr = {}
    @visitsArr.forEach (v)=>
      d = new Date v.visitTime
      yr = d.getFullYear()
      (@daysByYr[yr] ?= []).push Utils.dayOnYear(d)
    @daysByYr
      
        
class @Stats
  constructor: (config, @callback)->
    @data =
      pageViews: null
      sites: 0
      pagesPerSite: null
      searchQueries: null
      bounceRate: null
      
    @sites = {}
    @search config
    
  search: (config)->
    @settings =
      text: ''
      startTime: config.startTime
      endTime: config.endTime
      maxResults: MAX
    
    chrome.history.search @settings, (res)=> @analyze(res)
  
  analyze: (historyItems)->
    @data.pageViews = historyItems.length
    historyItems.forEach (item)=>
      @updateSites(item)
      @updateSearch(item)
      @updateMisc(item)
    @callback this
    
  updateSites: (item)->
    {hostName: host, path: pagePath} = Utils.parseUrl item.url
    if @sites[host]?
      @sites[host].addItem(item)
    else
      @data.sites++
      @sites[host] = new Site(item, host)
    
  updateSearch: (item)->
    if /^https?:\/\/(www\.)?(google|yahoo|bing)/.test item.url
      @data.searchQueries++
  
  updateMisc: (item)->
    
  relations: (callback)->
    sitesArr = []
    links = []
    ct = 0
    _.each @sites, (site)=>

      site.index = (sitesArr.push site) - 1
      site.updateVisits ()=>
        ct++
        site.getVisits().forEach (visit, i, arr)=>
          refId = visit.referringVisitId
          ref = visitsHash[refId]
          if ref? and ref != site
            ref.hasLink()
            site.hasLink()
            links.push
              source: ref
              target: site
          else if ref != site
            if unlinked[refId]
              unlinked[refId].push site
            else
              unlinked[refId] = [site]
        @jitNormalize(unlinked, sitesArr, links, callback) if ct == @data.sites
            

  jitNormalize: (unlinked, sites, links, callback)->
    _.each unlinked, (unlinks, id)->
      if visitsHash[id]?
        visitsHash[id].hasLink()
        unlinks.forEach (link)->
          link.hasLink()
          links.push
            source: visitsHash[id]
            target: link    
            
    retSites = []
    sites.forEach (site)->
      if site.linked
        site.index = retSites.push(site) - 1
        
    cache = {}
    links = links.filter (link)->
      link.source = link.source.index
      link.target = link.target.index
      link.value = 1
      cached = cache[link.source + ',' + link.target]
      if cached
        cached.value++;
        return false
      else
        cache[link.source + ',' + link.target] = link
        return true
      
    callback
      nodes: retSites
      links: links


