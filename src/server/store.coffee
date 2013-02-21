derbyAuth = require('derby-auth/store')

###
Setup read / write access
@param store
###

module.exports.customAccessControl = (store) ->
  userAccess(store)
  partySystem(store)
  REST(store)

###
  General user access
###
userAccess = (store) ->

  store.readPathAccess "users.*", -> # captures, accept, err ->
    err = arguments[arguments.length - 1]
    return err(derbyAuth.SESSION_INVALIDATED_ERROR) if derbyAuth.sessionInvalidated(@)

    accept = arguments[arguments.length - 2]
    uid = arguments[0]
    accept (uid is @session.userId) or @session.req?._isServer

  store.writeAccess "*", "users.*", -> # captures, value, accept, err ->
    err = arguments[arguments.length - 1]
    return err(derbyAuth.SESSION_INVALIDATED_ERROR) if derbyAuth.sessionInvalidated(@)

    accept = arguments[arguments.length-2]
    captures = arguments[0].split('.')
    uid = captures.shift()
    attrPath = captures.join('.') # new array shifted left, after shift() was run

    # public access to users.*.party.invitation (TODO, lock down a bit more)
    if (attrPath == 'party.invitation')
      return accept(true)

    # Same session (user.id = this.session.userId)
    if (uid is @session.userId) or @session.req?._isServer
      return accept(true)

    accept(false)

  store.writeAccess "*", "users.*.balance", (id, newBalance, accept, err) ->
    return err(derbyAuth.SESSION_INVALIDATED_ERROR) if derbyAuth.sessionInvalidated(@)

    oldBalance = @session.req?._racerModel?.get("users.#{id}.balance") || 0
    purchasingSomethingOnClient = newBalance < oldBalance
    accept(purchasingSomethingOnClient or @session.req?._isServer)

  store.writeAccess "*", "users.*.flags.ads", -> # captures, value, accept, err ->
    err = arguments[arguments.length - 1]
    return err(derbyAuth.SESSION_INVALIDATED_ERROR) if derbyAuth.sessionInvalidated(@)

    accept(@session.req?._isServer)


###
  REST
  Get user with API token
###
REST = (store) ->
  store.query.expose "users", "withIdAndToken", (uid, token) ->
    @byId(uid)
      .where('apiToken').equals(token)
      .one

  store.queryAccess "users", "withIdAndToken", (uid, token, accept, err) ->
    return accept(true) if uid && token
    accept(false) # only user has id & token


###
  Party permissions
###
partySystem = (store) ->
  store.query.expose "users", "party", (ids) ->
    @where("id").within(ids)
      .only('stats',
            'items',
            'party',
            'preferences',
            'auth.local.username',
            'auth.facebook.displayName')

  store.queryAccess "users", "party", (ids, accept, err) ->
    accept(true) # no harm in public user stats

  store.query.expose "parties", "withId", (id) ->
    @where("id").equals(id)
  store.queryAccess "parties", "withId", (id, accept, err) ->
    accept(true)

  store.readPathAccess "parties.*", ->
    accept = arguments[arguments.length-2]
    accept(true)

  store.writeAccess "*", "parties.*", ->
    accept = arguments[arguments.length-2]
    accept(true)
