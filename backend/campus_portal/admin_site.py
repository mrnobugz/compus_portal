from django.contrib.admin import AdminSite
from django.template.response import TemplateResponse


class CampusAdminSite(AdminSite):
    site_header = 'Campus Portal'
    site_title = 'Campus Portal Admin'
    index_title = 'Analytics Dashboard'
    index_template = 'admin/index.html'
    enable_nav_sidebar = False

    def index(self, request, extra_context=None):
        from api.dashboard_context import build_dashboard_context

        context = {
            **self.each_context(request),
            'title': self.index_title,
            'subtitle': None,
            'app_list': self.get_app_list(request),
            **build_dashboard_context(),
            **(extra_context or {}),
        }
        request.current_app = self.name
        return TemplateResponse(request, self.index_template, context)


campus_admin_site = CampusAdminSite(name='campus_admin')
