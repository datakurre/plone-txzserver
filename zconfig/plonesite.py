from zope.component.hooks import setSite
from Products.CMFPlone.factory import addPloneSite
import transaction
import os

ADMIN_USER = 'admin'
ADMIN_PASSWD = os.environ.get('PLONE_ADMIN_PASSWORD', 'admin')

app.acl_users._doAddUser(ADMIN_USER, ADMIN_PASSWD, ['Manager'], [])

if os.environ.get('PLONE_SITENAME', 'Plone') not in app.objectIds():
    site_id = os.environ.get('PLONE_SITENAME', 'Plone')
    addPloneSite(app, site_id)
    plone = getattr(app, site_id)
    setSite(plone)

    stool = plone.portal_setup
    for profile in [
        'profile-plonetheme.barceloneta:default',
    ]:
        try:
            stool.runAllImportStepsFromProfile(
                profile, dependency_strategy='reapply')
        except:  # noqa
            stool.runAllImportStepsFromProfile(profile)

transaction.commit()
