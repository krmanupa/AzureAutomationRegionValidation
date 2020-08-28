workflow psWF-job-test
{
For ($i=0; $i -le 600; $i++) {
    "i = $i" 
    Checkpoint-Workflow
    Start-Sleep -Seconds 1
    }
}