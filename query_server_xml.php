<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$securityKey = 'lazsql_392';
$getEnumValues = false;

$server   = 'localhost';
$database = '';
$username = '';
$password = '';
$charset  = ''; //leer lassen
$sql      = 'SELECT * from objekt'; //debug

/*
$server = getFormValue('host', $server);
$database = getFormValue('db', $database);
$username = getFormValue('user', $username);
$password = getFormValue('pass', $password); */
$charset = getFormValue('charset', $charset);
$sql = getFormValue('sql', $sql);


// --------------------------------------------------------


$mysql_data_type_hash = array (
    1 => 'tinyint',
    2 => 'smallint',
    3 => 'int',
    4 => 'float',
    5 => 'double',
    7 => 'timestamp',
    8 => 'bigint',
    9 => 'mediumint',
    10 => 'date',
    11 => 'time',
    12 => 'datetime',
    13 => 'year',
    16 => 'bit',
    252 => 'blob', //is currently mapped to all text and blob types (MySQL 5.0.51a)
    253 => 'varchar',
    254 => 'char',
    246 => 'decimal',
);


function FixEncoding($x)
{
    if (mb_detect_encoding($x) == 'UTF-8') {
        return $x;
    } else {
        return utf8_encode($x);
    }
}

function enum_values($db,$table_name, $column_name) {
    $sql = "
        SELECT COLUMN_TYPE 
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '" . $db->real_escape_string($table_name) . "' 
            AND COLUMN_NAME = '" . $db->real_escape_string($column_name) . "'
    ";
    $result = $db->query($sql) or die ($db->error);
    $row = $result->fetch_array(MYSQLI_ASSOC);
    $enum_list = str_replace("'", "", substr($row['COLUMN_TYPE'], 5, (strlen($row['COLUMN_TYPE'])-6)));
    return $enum_list;
}

if (getFormValue('key') != $securityKey) {
    exit('Permission denied');
}

$db = new mysqli($server, $username, $password);
if (!$db) {
    exit('Could not connect: ' . $db->error);
}

if (!$db->select_db($database)) {
    $error = 'Cannot select database: ' . $db->error;
    @$db->close();
    exit($error);
}

if (strlen($charset) > 0) {
    if (!$db->query("SET CHARACTER SET '{" . $charset . "}'")) {
        $error = 'Invalid character set: ' . $db->error;
        @$db->close();
        exit($error);
    }
}



$result = @$db->query($sql);

if (!$result) {
    exit($db->error);
}
if ($result instanceof mysqli_result) {
    $doc = new DomDocument('1.0', 'UTF-8');
    $doc->formatOutput = true; //debugging

    $root = $doc->createElement('DATAPACKET');
    $root = $doc->appendChild($root);
    $root->setAttribute('Version', '2.0');

    $meta = $doc->createElement('METADATA');
    $meta = $root->appendChild($meta);

    $no_of_fields = $result->field_count;
    $fielddefs = $doc->createElement('FIELDS');
    $fielddefs = $meta->appendChild($fielddefs);

    $tabledescs = [];
    $i = 0;
    while ($i < $no_of_fields) {
        $fielddesc = $result->fetch_field_direct($i);
        $fieldname = $fielddesc->name;
        $tabl = $fielddesc->table;
        $fielddef = $doc->createElement('FIELD');
        $fielddef = $fielddefs->appendChild($fielddef);
        $thisfield_type = $mysql_data_type_hash[$fielddesc->type];
        $thisfield_length = $fielddesc->length;
        $thisfield_flags = $fielddesc->flags;
        $fielddef->setAttribute('fieldname', $fieldname);
        $fielddef->setAttribute('attrname', $tabl . '.' . $fieldname);
        $fielddef->setAttribute('fieldtype', $thisfield_type);
        $fielddef->setAttribute('width', $thisfield_length);
         if ($thisfield_flags & MYSQLI_PRI_KEY_FLAG) $fielddef->setAttribute('key', 'PRI');
         if ($thisfield_flags & MYSQLI_NOT_NULL_FLAG) $fielddef->setAttribute('null', 'NO');
         if ($thisfield_flags & MYSQLI_AUTO_INCREMENT_FLAG) $fielddef->setAttribute('extra', 'auto_increment');
         if ($getEnumValues && $thisfield_flags & MYSQLI_ENUM_FLAG) $fielddef->setAttribute('enum', enum_values($db,$tabl,$fieldname));
        $i++;
    }

    $no_of_records = $result->num_rows;
    $recorddata = $doc->createElement('ROWDATA');
    $recorddata = $root->appendChild($recorddata);

    $rowCount = 0;

    while ($row = $result->fetch_row()) {
        $rowCount++;
        $element = $doc->createElement('ROW');
        $element = $recorddata->appendChild($element);
        $cnt = 0;
        foreach ($row as $fieldname => $fieldvalue) {
            $ft = $result->fetch_field_direct($cnt)->type;
            $child = $doc->createElement('f' . $cnt);
            $child = $element->appendChild($child);
            if (is_numeric($fieldvalue) || $fieldvalue == '') {
                $value = $doc->createTextNode($fieldvalue);
            } else {
                if ($ft == MYSQLI_TYPE_BLOB || $ft == MYSQLI_TYPE_STRING || $ft ==MYSQLI_TYPE_VAR_STRING) {
                    //not ideal if blob is binary
                    $fieldvalue = FixEncoding($fieldvalue);
                }
                $value = $doc->createCDATASection($fieldvalue);
            }
            $value = $child->appendChild($value);
            $cnt++;
        } // foreach
    } // while
} else {
    return '';
}

@$result->free_result();
@$db->close();

echo $doc->saveXML();

unset($child);
unset($element);
unset($root);
unset($doc);

// --------------------------------------------------------

function getFormValue($name, $default = '')
{
    if (isset($_POST[$name])) {
        return stripslashes($_POST[$name]);
    } else {
        if (isset($_GET[$name])) {
            return stripslashes($_GET[$name]);
        } else {
            return $default;
        }
    }
}
