{#-
	F2x template for Python
	
	This template uses the BIND(C) interface to generate easy access to the wrapped
	contents using ctypes.
-#}

{##### Macros #####}
{%- macro arg_types(args) -%}
{%- for arg in args -%}
	{%- if arg.strlen %}ctypes.c_char_p
	{%- elif arg.ftype %}ctypes.c_void_p
	{%- elif arg.dims %}ctypes.POINTER(ctypes.POINTER({{ arg.pytype }}))
	{%- elif arg.intent == 'IN' %}{{ arg.pytype }}
	{%- else %}ctypes.POINTER({{ arg.pytype }})
	{%- endif %}
	{%- if not loop.last %}, {% endif %}
{%- endfor -%}
{%- endmacro -%}

{%- macro arg_names(args) -%}
{%- set names = [] %}
{%- for arg in args -%}
	{%- if arg.intent != 'OUT' %}{% do names.append(arg.name) %}
	{%- endif %}
{%- endfor -%}
{%- for name in names -%}
	{{ name }}{%- if not loop.last %}, {% endif %}
{%- endfor %}
{%- endmacro -%}

{%- macro arg_specs(args) %}
{%- for arg in args %}
{%- if arg.strlen %}
    {{ arg.name }}_intern = ctypes.create_string_buffer({% if arg.intent != 'OUT' %}{{ arg.name }}.encode('{{ config.get("parser", "encoding") }}'), {% endif %}{{ arg.strlen }})
{%- elif arg.ftype %}{% if arg.intent == 'OUT' %}
    {{ arg.name }}_intern = {{ arg.ftype }}(){% endif %}
{%- elif arg.dims %}
    {{ arg.name }}_intern = ({{ arg.pytype }}{% for dim in arg.dims %} * {{ dim }}{% endfor %})({% if arg.intent == 'IN' or arg.intent == 'INOUT' %}*{{ arg.name }}{% endif %})
{%- elif arg.intent != 'IN' %}
    {{ arg.name }}_intern = {{ arg.pytype }}({% if arg.intent == 'INOUT' %}{{ arg.name }}{% endif %})
{%- endif %}{% endfor %} 
{%- endmacro -%}

{%- macro call_args(args, outargs) -%}
{%- for arg in args -%}
    {%- if arg.strlen %}{{ arg.name }}_intern{%- if arg.intent != 'IN' %}{%- do outargs.append(arg.name + "_intern.value.decode('" + config.get("parser", "encoding") + "').rstrip()") -%}{% endif %}
    {%- elif arg.ftype %}{{ arg.name }}{% if arg.intent == 'OUT' %}_intern{% do outargs.append(arg.name + "_intern") %}{% elif arg.intent == 'INOUT' %}{% do outargs.append(arg.name) %}{% endif %}._ptr
    {%- elif arg.dims %}ctypes.byref(ctypes.cast({{ arg.name }}_intern, ctypes.POINTER({{ arg.pytype }})))
    {%- if arg.intent == 'OUT' or arg.intent == 'INOUT' %}{% do outargs.append(arg.name + "_intern[:]") %}{% endif %}
    {%- elif arg.intent == 'IN' -%}{{ arg.name }}
    {%- else -%}ctypes.byref({{ arg.name }}_intern)
    {%- do outargs.append(arg.name + "_intern.value") -%}
    {%- endif %}
    {%- if not loop.last %}, {% endif %}
{%- endfor %}
{%- endmacro -%}

{#-######################-#}
{#- Template starts here -#}
# This file was generated by F2x. Please do not change directly!

import ctypes
import os

{%- if config.has_section('pyimport') %}
{% for import_module in config.options('pyimport') %}
from {{ import_module }} import {{ config.get('pyimport', import_module) }}
{%- endfor %}
{%- endif %}

{{ module.name }} = ctypes.cdll.LoadLibrary(os.path.join(os.path.dirname(__file__), '{{ config.get('generate', 'dll') }}'))

{%- for type in module.types %}

#######################################
# {{ type.name }} from {{ module.name }}
#

{{ module.name }}.{{ type.name }}_new.restype = ctypes.c_void_p
{{ module.name }}.{{ type.name }}_new.argtypes = []
{{ module.name }}.{{ type.name }}_free.restype = None
{{ module.name }}.{{ type.name }}_free.argtypes = [ctypes.c_void_p]
{%- for field in type.fields %}
{%- if field.ftype and field.dims %}
# Skipping {{ type.name }}.{{ field.name }}: Arrays of derived types not yet supported
{%- else %}
{%- if field.getter == 'function' %}
{{ module.name }}.{{ type.name }}_get_{{ field.name }}.restype = {{ field.pytype }}
{{ module.name }}.{{ type.name }}_get_{{ field.name }}.argtypes = [ctypes.c_void_p]
{%- elif field.getter == 'subroutine' %}
{{ module.name }}.{{ type.name }}_get_{{ field.name }}.restype = None
{{ module.name }}.{{ type.name }}_get_{{ field.name }}.argtypes = [ctypes.c_void_p, {{ arg_types([field]) }}]
{%- endif %}
{%- if field.setter == 'subroutine' %}
{{ module.name }}.{{ type.name }}_set_{{ field.name }}.restype = None
{{ module.name }}.{{ type.name }}_set_{{ field.name }}.argtypes = [ctypes.c_void_p, {{ field.pytype }}]
{%- endif %}
{%- endif %}
{%- endfor %}
class {{ type.name }}(object):
    def __init__(self, ptr=None, is_ref=True):
        if ptr is None:
            self._ptr = {{ module.name }}.{{ type.name }}_new()
            self._is_ref = False
        else:
            self._ptr = ptr
            self._is_ref = is_ref
    
    def __del__(self):
        if not self._is_ref:
            {{ module.name }}.{{ type.name }}_free(self._ptr)
    {%- for field in type.fields %}
    {%- if field.ftype and field.dims %}
    
    # Arrays of derived types not yet supported
    
    {%- else %}
    
    def get_{{ field.name }}(self):
    	{%- if field.ftype %}
        if not hasattr(self, "_{{ field.name }}"):
            self._{{ field.name }}_intern = {{ module.name }}.{{ type.name }}_get_{{ field.name }}(self._ptr)
            self._{{ field.name }} = {{ field.ftype }}(self._{{ field.name }}_intern)
        return self._{{ field.name }}
    	{%- elif field.getter == 'function' %}
        return {{ module.name }}.{{ type.name }}_get_{{ field.name }}(self._ptr)
    	{%- elif field.dims %}
        if not hasattr(self, "_{{ field.name }}"):
            self._{{ field.name }}_intern = ctypes.POINTER({{ field.pytype }})()
            {{ module.name }}.{{ type.name }}_get_{{ field.name }}(self._ptr, ctypes.byref(self._{{ field.name }}_intern))
            self._{{ field.name }} = ({{ field.pytype }}{% for dim in field.dims %} * {{ dim }}{% endfor %}).from_address(ctypes.addressof(self._{{ field.name }}_intern.contents))
        return self._{{ field.name }}
    	{%- else %}
    	{{ field.name }}_intern = {{ field.pytype }}()
    	{{ module.name }}.{{ type.name }}_get_{{ field.name }}(self._ptr, ctypes.byref(self._{{ field.name }}_intern))
        return {{ field.name }}_intern.value
    	{%- endif %}
    {%- if field.setter == 'subroutine' %}
    
    def set_{{ field.name }}(self, value):
        {{ module.name }}.{{ type.name }}_set_{{ field.name }}(self._ptr, value)
    
    {{ field.name }} = property(get_{{ field.name }}, set_{{ field.name }})
    {%- else %}
    
    {{ field.name }} = property(get_{{ field.name }})
    {%- endif %}
    {%- endif %}
    {%- endfor %}
{%- endfor -%}

{%- if config.has_section('export') %}
{%- set exports = config.options('export') %}

#######################################
# Exported functions and subroutines
#
{%- for subroutine in module.subroutines %}
{%- if subroutine.name.lower() in exports %}
{%- set export_name = config.get('export', subroutine.name.lower()) %}
{%- set outargs = [] %}

{{ module.name }}.{{ export_name }}.restype = None
{{ module.name }}.{{ export_name }}.argtypes = [{{ arg_types(subroutine.args) }}]
def {{ subroutine.name }}({{ arg_names(subroutine.args) }}):
    {{- arg_specs(subroutine.args) }}
    {{ module.name }}.{{ export_name }}({{ call_args(subroutine.args, outargs) }})
    {%- if outargs %}
    return {% for outarg in outargs %}{{ outarg }}{% if not loop.last %}, {% endif %}{% endfor %}
    {%- endif %}

{%- endif %}
{%- endfor %}
{%- for function in module.functions %}
{%- if function.name.lower() in exports %}
{%- set export_name = config.get('export', function.name.lower()) %}
{%- set outargs = [] %}
{%- if function.ret.getter == 'function' %}

{{ module.name }}.{{ export_name }}.restype = {{ function.ret.pytype }}
{{ module.name }}.{{ export_name }}.argtypes = [{{ arg_types(function.args) }}]
def {{ function.name }}({{ arg_names(function.args) }}):
    {{- arg_specs(function.args) }}
    {{ function.name }}_intern = {{ module.name }}.{{ export_name }}({{ call_args(function.args, outargs) }})
    return {{ function.name }}_intern{% if outargs %}{% for outarg in outargs %}, {{ outarg }}{% endfor %}{% endif %}
    

{%- elif function.ret.getter == 'subroutine' %}

{{ module.name }}.{{ export_name }}.restype = None
{{ module.name }}.{{ export_name }}.argtypes = [{{ arg_types(function.args) }}{% if function.args %}, {% endif %}{{ arg_types([function.ret]) }}]
def {{ function.name }}({{ arg_names(function.args) }}):
    {{- arg_specs(function.args) }}
    {%- if function.ret.strlen %}
    {{ function.name }}_value = ctypes.create_string_buffer({{ function.ret.strlen }})
    {%- elif function.ret.dims %}
    {{ function.name }}_value = ({{ function.ret.pytype }}{% for dim in function.ret.dims %} * {{ dim }}{% endfor %})()
    {%- else %}
    {{ function.name }}_value = {{ function.ret.pytype }}()
    {%- endif %}
    {{ module.name }}.{{ export_name }}({{ call_args(function.args, outargs) }}{% if function.args %}, {% endif %}
    {%- if function.ret.strlen -%}
    {{ function.name }}_value
    {%- elif function.ret.dims -%}
    ctypes.byref(ctypes.cast({{ function.name }}_value, ctypes.POINTER({{ function.ret.pytype }})))
    {%- else -%}
    ctypes.byref({{ function.name }}_value)
    {%- endif -%})
    return {{ function.name }}_value{% if not function.ret.dims %}.value{% endif %}{% if outargs %}{% for outarg in outargs %}, {{ outarg }}.value{% endfor %}{% endif %}

{%- endif%}
{%- endif %}
{%- endfor %}
{%- endif %}

