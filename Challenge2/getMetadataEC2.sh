usage() {
  echo "Usage: $0 [-h] [-t TAG_NAME]"
  echo "Create AMI from EC2 insances from filtered tags"
  exit 1
}

get_opts() {
  local opt OPTARG OPTIND
  while getopts "ht:" opt ; do
    case "$opt" in
      h) usage ;;
      t) tag_name="$OPTARG" ;;
      \?) echo "ERROR: Invalid option -$OPTARG"
          usage ;;
    esac
  done
  shift $((OPTIND-1))
}

validate_opts() {
  if [ -z "$tag_name" ] ; then
    echo "You must pass a tag_name with -t"
    usage
  fi
}

function HorizontalRule(){
	echo "============================================================"
}

describe_instances() {
  local filter="Name=tag:$tag_name,Values=Yes"
  aws ec2 describe-instances --filters "$filter" --region us-east-1 --query "Reservations[*].Instances[*].{Instance:InstanceId}" --output table
}

get_instance_id() {
  local filter="Name=tag:$tag_name,Values=Yes"
  instance_id="$(aws ec2 describe-instances --filters "$filter" --region us-east-1 --query "Reservations[*].Instances[*].{Instance:InstanceId}")"
}

get_instance_type() {
  instance_type="$(aws ec2 describe-instances --instance-id $instance --region us-east-1 --query "Reservations[*].Instances[*].{Type:InstanceType}")"
  HorizontalRule
  printf "Instance Type : $instance_type\n"
}

get_instance_subnet() {
  instance_subnet="$(aws ec2 describe-instances --instance-id $instance --region us-east-1 --query "Reservations[*].Instances[*].{Subnet:SubnetId}")"
  HorizontalRule
  printf "Instance Subnet-ID : $instance_subnet\n"
}

get_instance_vpcid() {
  instance_vpc_id="$(aws ec2 describe-instances --instance-id $instance --region us-east-1 --query "Reservations[*].Instances[*].{VpcId:VpcId}")"
  HorizontalRule
  printf "Instance VPC-ID : $instance_vpc_id\n"
}

get_instance_keypair() {
  instance_keypair="$(aws ec2 describe-instances --instance-id $instance --region us-east-1 --query "Reservations[*].Instances[*].{KeyName:KeyName}")"
  HorizontalRule
  printf "Instance Key-Pair : $instance_keypair\n"
}

get_instance_security_group() {
  instance_security_group="$(aws ec2 describe-instances --instance-id $instance --region us-east-1 --query "Reservations[].Instances[].SecurityGroups[].GroupId[]")"
  HorizontalRule
  printf "Instance Security Group : $instance_security_group\n"
}

ec2-create-image() {
AMI_NAME="$instance - $DATE"
AMI_DESCRIPTION="$instance Backup - $DATE"
INSTANCE_ID=$instance
HorizontalRule
printf "Requesting AMI for instance $instance...\n"
printf "AMI_NAME : $AMI_NAME\n"
printf "AMI_DESCRIPTION : $AMI_DESCRIPTION\n"
ami_id="$(aws ec2 create-image --instance-id $instance --name "$AMI_NAME" --description "$AMI_DESCRIPTION")"
printf "AMI ID : $ami_id\n"
printf "AMI request complete!\n"

}

function TagAMI(){
	echo
	for i in {1..10}; do
		printf "."
		sleep 1
	done
	echo
	echo
	echo "Creating Backup Tag for AMI ID: $ami_id"
	Tag="$(aws ec2 create-tags --resources "$ami_id" --tags "Key=Backup,Value=$instance-$DATE")"
	if [ ! $? -eq 0 ]; then
		fail "$Tag"
	fi
    echo "Created Backup Tag for AMI ID: $Tag"
}

function CheckState(){
	AMIdescr="$(aws ec2 describe-images --image-ids "$ami_id")"
	if [ ! $? -eq 0 ]; then
		fail "$AMIdescr"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AMIdescr: $AMIdescr"
	fi
	AMIstate="$(aws ec2 describe-images --image-ids "$ami_id" --query "Images[].State[]")"
    echo "Checking AMI State $AMIstate"
	if [ ! $? -eq 0 ]; then
		fail "$AMIstate"
	fi
	if [[ $DEBUGMODE = "1" ]]; then
		echo "AMIstate: $AMIstate"
	fi
	while [ "$AMIstate" != "available" ]; do
		for i in {1..30}; do
			printf "."
			sleep 1
		done
		CheckState
	done
}

export AWS_DEFAULT_OUTPUT="text"
DATE=$(date +%Y-%m-%d_%H-%M) 
get_opts "$@"
validate_opts
describe_instances
get_instance_id
for instance in $instance_id;
  do
    HorizontalRule
    ec2-create-image $instance
    CheckState $ami_id
    TagAMI $ami_id
    get_instance_type $instance
    get_instance_subnet $instance
    get_instance_vpcid $instance
    get_instance_keypair $instance
    get_instance_security_group $instance
  done
