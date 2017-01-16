{#-##################################################################################################################-#}
{#- F2x 'bindc' main template.                                                                                       -#}
{#-                                                                                                                  -#}
{#- This template generates a FORTRAN wrapper module that provides `BIND(C)` interfaces to FORTRAN derived types,    -#}
{#- `FUNCTION`s and `SUBROUTINE`s.                                                                                   -#}
{#-##################################################################################################################-#}


{#- Import helper libraries. -#}
{%- import "calls.f90.tl" as calls -%}
{%- import "types.f90.tl" as types -%}

! This module was generated by the F2x 'bindc' template. Please do not modify it directly.
MODULE {{ module.name }}_WRAP
    USE C_INTERFACE_MODULE
    USE {{ module.name }}
{%- for module_name in module.uses %}
    USE {{ module_name }}
{%- endfor %}

    IMPLICIT NONE

CONTAINS
{%- for type in module.types  %}
    {{ types.export_type(type) }}
{% endfor %}

{%- if module.methods %}
    !===================================================================================================================
    ! Exported subroutines and functions
    {%- for method in module.methods %}

    {{ calls.export_method(method) }}
    {% endfor %}
{%- endif %}
END
