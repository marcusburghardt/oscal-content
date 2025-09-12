#!/bin/bash
set -e

# This script verify OSCAL contents using complyctl and OpenSCAP,
# make sure OSCAL align with OpenSCAP in rules.
# https://issues.redhat.com/browse/CPLYTM-254
# usage: ./scripts/verify-OSCAL-contents.sh "$catalogs" "$profiles" "$component_definitions" "$product_name"

# OSCAL Catalogs relative path string, multiple elements separate by space
catalogs=$1
# OSCAL Profiles relative path string, multiple elements separate by space
profiles=$2
# OSCAL Component Definitions relative path string, multiple elements separate by space
component_definitions=$3
# test product name
product=$4

TRESTLE_PREFIX="trestle://"
RULE_ALIGNMENT_THRESHOLD_PERCENTAGE=60
COMPLY_TIME_WORKSPACE="/usr/share/complytime"
# array to store verified files, avoid testing one file multiple times
verified_files=()

# A function to check if an element exists in an array.
# Returns 0 if found, 1 if not found.
# Usage: contains_element "element_to_find" "${array[@]}"
contains_element() {
  local element_to_find="$1"
  shift # Remove the first argument so that the rest are the array elements
  local array_to_search=("$@")

  for element in "${array_to_search[@]}"; do
    if [[ "$element" == "$element_to_find" ]]; then
      return 0 # Found the element
    fi
  done

  return 1 # Element was not found
}

# setup OSCAL content for complyctl
setup_complyctl_files() {
  local catalog_path="$1"
  local profile_path="$2"
  local cd_path="$3"
  # get framework id
  framework_id=$(jq -r '.["component-definition"].components[0]."control-implementations"[0].props[] |
   select(.name="Framework_Short_Name").value' "$cd_path")
  # clean complyctl dir
  rm -f $COMPLY_TIME_WORKSPACE/bundles/*
  rm -f $COMPLY_TIME_WORKSPACE/controls/*
  # copy OSCAL contents to complyctl dir
  cp "$cd_path" $COMPLY_TIME_WORKSPACE/bundles
  cp "$profile_path" "$catalog_path" $COMPLY_TIME_WORKSPACE/controls
  # Update trestle path
  sed -i "s|trestle://$catalog_path|trestle://controls/catalog.json|" $COMPLY_TIME_WORKSPACE/controls/profile.json
  sed -i "s|trestle://$profile_path|trestle://controls/profile.json|" $COMPLY_TIME_WORKSPACE/bundles/component-definition.json
  echo "$framework_id"
}

# running complyctl commands to test OSCAL contents
running_complyctl_cmds() {
  local framework_id="$1"
  # Running complyctl commands
  complyctl list --plain
  complyctl plan "$framework_id"
  complyctl generate
}

# calculate rule alignment between OSCAL and openscap
calculate_rule_alignment() {
  # get xccdf version
  xccdf_version=$(grep -oP 'xccdf/\K[0-9\.]+' complytime/openscap/policy/tailoring_policy.xml)
  # get openscap select item number form tailoring_policy.xml
  select_count=$(xmlstarlet sel -t -v "count(//xccdf-$xccdf_version:select)" complytime/openscap/policy/tailoring_policy.xml)
  # get OSCAL rule number from assessment-plan.json
  oscal_rule_count=$(jq -e -r '.["assessment-plan"]."assessment-assets".components[0].props | map(select(.name=="Check_Id")) | length'\
   complytime/assessment-plan.json)
  # calculate misalignment rule %
  result=$(echo "scale=3; (($oscal_rule_count - $select_count) / $oscal_rule_count) * 100" | bc)
  echo "$result"
}

# judge if rule alignment % meet requirement
is_rule_align() {
  local alignment_percentage="$1"

  echo "Rule alignment between OSCAL and openscap is $alignment_percentage%"
  if (( $(echo "$alignment_percentage < $RULE_ALIGNMENT_THRESHOLD_PERCENTAGE" | bc) )); then
    echo "Rule alignment between OSCAL and openscap lower than \
    $RULE_ALIGNMENT_THRESHOLD_PERCENTAGE%, please check OSCAL contents"
    exit 1
  fi
}

# Test component definitions
for cd in $component_definitions; do
  # get profile path
  profile_path=$(jq -r '.["component-definition"].components[0]."control-implementations"[0].source' "$cd")
  # remove trestle:// prefix
  profile_path=${profile_path#"$TRESTLE_PREFIX"}
  # get catalog path
  catalog_path=$(jq -r '.["profile"].imports[0].href' "$profile_path")
  catalog_path=${catalog_path#"$TRESTLE_PREFIX"}

  echo "Testing $cd with $profile_path and $catalog_path"
  framework_id=$(setup_complyctl_files "$catalog_path" "$profile_path" "$cd")
  running_complyctl_cmds "$framework_id"
  result=$(calculate_rule_alignment)
  is_rule_align "$result"

  verified_files+=("$cd" "$profile_path" "$catalog_path")
  echo
done

# Test profiles
for profile in $profiles; do
  if contains_element "$profile" "${verified_files[@]}"; then
    continue
  fi

  # get catalog path
  catalog_path=$(jq -r '.["profile"].imports[0].href' "$profile")
  catalog_path_r=${catalog_path#"$TRESTLE_PREFIX"}
  # find a component definition to test
  cd_path=$(grep -r "$profile" component-definitions/ | awk 'NR==1 {print $1}')
  # remove suffix :
  cd_path_r=${cd_path%:}

  echo "Testing $profile with $catalog_path_r and $cd_path_r"
  framework_id=$(setup_complyctl_files "$catalog_path_r" "$profile" "$cd_path_r")
  running_complyctl_cmds "$framework_id"
  result=$(calculate_rule_alignment)
  is_rule_align "$result"

  verified_files+=("$profile" "$catalog_path_r" "$cd_path_r")
  echo
done

# Test catalogs
for catalog in $catalogs; do
  if contains_element "$catalog" "${verified_files[@]}"; then
    continue
  fi
  # find a profile
  profile_path=$(grep -r "$catalog" profiles/ | grep "$product" | awk 'NR==1 {print $1}')
  # if can not find product related OSCAL profile, skip
  if [[ -z "$profile_path" ]]; then
    continue
  fi
  # remove suffix :
  profile_path_r=${profile_path%:}
  # find a component definition to test
  cd_path=$(grep -r "$profile_path_r" component-definitions/ | awk 'NR==1 {print $1}')
  # remove suffix :
  cd_path_r=${cd_path%:}

  echo "Testing $catalog with $profile_path_r and $cd_path_r"
  framework_id=$(setup_complyctl_files "$catalog" "$profile_path_r" "$cd_path_r")
  running_complyctl_cmds "$framework_id"
  result=$(calculate_rule_alignment)
  is_rule_align "$result"

  echo
done
