package test

#necessary modules
import (
    "fmt"
    "net/http"
    "os"
    "testing"
    "time"

    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/s3"
    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/gruntwork-io/terratest/modules/random"
    "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTerraformAwsS3Bucket(t *testing.T) {
    // Give the AWS resources a unique ID to prevent naming conflicts with existing resources
    uniqueID := random.UniqueId()

    // Set the Terraform options
    terraformOptions := &terraform.Options{
        TerraformDir: "./terraform",
        Vars: map[string]interface{}{
            "s3_bucket_name": fmt.Sprintf("test-bucket-%s", uniqueID),
        },
    }

    // Clean up resources after the test has finished
    defer terraform.Destroy(t, terraformOptions)

    // Create the S3 bucket using Terraform
    terraform.InitAndApply(t, terraformOptions)

    // Verify that the S3 bucket exists
    s3BucketName := terraform.Output(t, terraformOptions, "s3_bucket_name")
    aws.AssertS3BucketExists(t, aws.GetRegion(), s3BucketName)

    // Verify that the S3 bucket contains the expected files
    currentTime := time.Now().Format(time.RFC3339)
    expectedFiles := []string{"test1.txt", "test2.txt"}
  
    for _, expectedFile := range expectedFiles {
        actualKey := aws.FindS3BucketObjectKey(t, aws.GetRegion(), s3BucketName, expectedFile)
        expectedKey := fmt.Sprintf("%s/%s", uniqueID, expectedFile)
        if !strings.Contains(actualKey, expectedKey) {
            t.Errorf("Unexpected S3 object key for file %s. Expected %s, but got %s", expectedFile, expectedKey, actualKey)
        }
        actualContent := aws.GetS3ObjectContents(t, aws.GetRegion(), s3BucketName, actualKey)
        if actualContent != currentTime {
            t.Errorf("Unexpected content for file %s. Expected %s, but got %s", expectedFile, currentTime, actualContent)
        }
    }

    // Verify that the files are reachable via the ALB
    albDNSName := terraform.Output(t, terraformOptions, "alb_dns_name")
    for _, expectedFile := range expectedFiles {
        response := aws.GetUrlResponse(t, fmt.Sprintf("http://%s/%s", albDNSName, expectedFile))
        if response.StatusCode != 200 {
            t.Errorf("Unexpected status code for file %s. Expected 200, but got %d", expectedFile, response.StatusCode)
        }
        responseContent := aws.GetUrlContents(t, fmt.Sprintf("http://%s/%s", albDNSName, expectedFile))
        if responseContent != currentTime {
            t.Errorf("Unexpected content for file %s. Expected%s, but got %s", expectedFile, currentTime, responseContent)
}
}
}


