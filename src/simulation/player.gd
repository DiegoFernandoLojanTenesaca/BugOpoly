class_name BPlayer
extends RefCounted

var id: int = 0
var pname: String = ""
var is_bot: bool = false
var color: Color = Color.WHITE
var piece: String = ""
var budget: int = 0
var position: int = 0
var owned: Array = []
var notes: String = ""
var bankrupt: bool = false
var jailed: int = 0
var debt: int = 0  # deuda técnica acumulada (cobra interés cada turno)

# Cartas de habilidad: hotfix (limpia deuda), rollback (recupera último gasto),
# feature_flag (próxima renta gratis).
var abilities: Array = []
var last_expense: int = 0
var flag_active: bool = false

# Estadísticas para la pantalla de fin de partida.
var stat_props: int = 0
var stat_builds: int = 0
var stat_rent_got: int = 0
var stat_rent_paid: int = 0
var stat_challenges: int = 0
var stat_debt_paid: int = 0
