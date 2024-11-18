// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Delance {
    address public owner;

    enum RequestStatus { Pending, Accepted, Rejected, Completed }

    struct Student {
        uint256 studentId; 
        address studentAddress;
        string pseudonym;
        string skills;
        uint256 priceInWei;
        bool isAvailable;
    }

    struct Request {
        uint256 requestId;
        address client;
        address studentAddress;
        uint256 amount;
        RequestStatus status;
        bool isDisputeRaised;
        bool isWorkConfirmed;
        string contactInfo;
    }

    mapping(address => bool) public isClient;
    mapping(uint256 => Student) public studentsById;
    mapping(uint256 => Request) public requests;
    uint256 public requestCounter;
    uint256 public studentCounter;
    mapping(address => uint256) public studentIdsByAddress;
    mapping(address => uint256[]) public clientRequests; // Client => Request IDs
    mapping(address => uint256[]) public studentRequests; // Student => Request IDs

    address[] public studentAddresses;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action");
        _;
    }

    modifier onlyClient() {
        require(isClient[msg.sender], "You must be a registered client");
        _;
    }

    modifier onlyStudent(uint256 _studentId) {
        require(studentIdsByAddress[msg.sender] == _studentId, "You are not the student for this request");
        _;
    }

    modifier onlyConcernedParties(uint256 _requestId) {
        Request storage request = requests[_requestId];
        require(msg.sender == request.client || msg.sender == request.studentAddress, "You are not authorized to view this request");
        _;
    }

    event RegisteredAsClient(address client);
    event RegisteredAsStudent(uint256 studentId, address studentAddress, string pseudonym, string skills, uint256 priceInWei);
    event ServiceRequested(uint256 requestId, address client, address studentAddress, uint256 amount);
    event RequestAccepted(uint256 requestId, string contactInfo);
    event RequestRejected(uint256 requestId);
    event WorkConfirmed(uint256 requestId);
    event DisputeRaised(uint256 requestId);
    event DisputeResolved(uint256 requestId, bool clientWins);
    event StudentUpdated(uint256 studentId, string pseudonym, string skills, uint256 priceInWei);
    event StudentDeleted(uint256 studentId);

    constructor() {
        owner = msg.sender;
    }

    function registerAsClient() public {
        require(!isClient[msg.sender], "Already registered as a client");
        isClient[msg.sender] = true;
        emit RegisteredAsClient(msg.sender);
    }

    function registerAsStudent(string memory _pseudonym, string memory _skills, uint256 _priceInWei) public {
        require(studentIdsByAddress[msg.sender] == 0, "Already registered as a student");
        studentCounter++;
        studentsById[studentCounter] = Student(studentCounter, msg.sender, _pseudonym, _skills, _priceInWei, true);
        studentAddresses.push(msg.sender);
        studentIdsByAddress[msg.sender] = studentCounter;
        emit RegisteredAsStudent(studentCounter, msg.sender, _pseudonym, _skills, _priceInWei);
    }

    function updateStudentDetails(uint256 _studentId, string memory _pseudonym, string memory _skills, uint256 _priceInWei) public onlyStudent(_studentId) {
        Student storage student = studentsById[_studentId];
        student.pseudonym = _pseudonym;
        student.skills = _skills;
        student.priceInWei = _priceInWei;
        emit StudentUpdated(_studentId, _pseudonym, _skills, _priceInWei);
    }

    function deleteStudentListing(uint256 _studentId) public onlyStudent(_studentId) {
        Student storage student = studentsById[_studentId];
        student.isAvailable = false;
        emit StudentDeleted(_studentId);
    }

    function viewStudents() public view returns (Student[] memory) {
        Student[] memory allStudents = new Student[](studentCounter);
        for (uint256 i = 1; i <= studentCounter; i++) {
            allStudents[i - 1] = studentsById[i];
        }
        return allStudents;
    }

    function requestService(uint256 _studentId) public payable onlyClient {
        require(studentsById[_studentId].studentAddress != address(0), "Student not registered");
        require(studentsById[_studentId].isAvailable, "Student is not available");

        uint256 amountInWei = studentsById[_studentId].priceInWei;
        require(msg.value >= amountInWei, "Insufficient payment");

        requestCounter++;
        requests[requestCounter] = Request(
            requestCounter,
            msg.sender,
            studentsById[_studentId].studentAddress,
            msg.value,
            RequestStatus.Pending,
            false,
            false,
            ""
        );

        clientRequests[msg.sender].push(requestCounter);
        studentRequests[studentsById[_studentId].studentAddress].push(requestCounter);

        emit ServiceRequested(requestCounter, msg.sender, studentsById[_studentId].studentAddress, msg.value);
    }

    function acceptRequest(uint256 _requestId, string memory _contactInfo) public onlyConcernedParties(_requestId) {
        Request storage request = requests[_requestId];
        require(request.status == RequestStatus.Pending, "Request already handled");

        request.status = RequestStatus.Accepted;
        request.contactInfo = _contactInfo;
        emit RequestAccepted(_requestId, _contactInfo);
    }

    function rejectRequest(uint256 _requestId) public onlyConcernedParties(_requestId) {
        Request storage request = requests[_requestId];
        require(request.status == RequestStatus.Pending, "Request already handled");

        request.status = RequestStatus.Rejected;
        address client = request.client;
        uint256 amount = request.amount;
        delete requests[_requestId];

        payable(client).transfer(amount);
        emit RequestRejected(_requestId);
    }

    function confirmWork(uint256 _requestId) public onlyConcernedParties(_requestId) {
        Request storage request = requests[_requestId];
        require(request.status == RequestStatus.Accepted, "Request not accepted");
        require(!request.isWorkConfirmed, "Work already confirmed");

        request.isWorkConfirmed = true;
        request.status = RequestStatus.Completed;
        address student = request.studentAddress;
        uint256 amount = request.amount;

        payable(student).transfer(amount);
        emit WorkConfirmed(_requestId);
    }

    function raiseDispute(uint256 _requestId) public onlyConcernedParties(_requestId) {
        Request storage request = requests[_requestId];
        require(request.status == RequestStatus.Accepted, "Request not accepted");
        require(!request.isWorkConfirmed, "Work already confirmed");
        require(!request.isDisputeRaised, "Dispute already raised");

        request.isDisputeRaised = true;
        emit DisputeRaised(_requestId);
    }

    function resolveDispute(uint256 _requestId, bool clientWins) public onlyOwner {
        Request storage request = requests[_requestId];
        require(request.isDisputeRaised, "No dispute to resolve");

        address client = request.client;
        address student = request.studentAddress;
        uint256 amount = request.amount;

        if (clientWins) {
            payable(client).transfer(amount);
        } else {
            payable(student).transfer(amount);
        }

        delete requests[_requestId];
        emit DisputeResolved(_requestId, clientWins);
    }

    function getStudentRequests() public view returns (Request[] memory) {
        uint256[] storage requestIds = studentRequests[msg.sender];
        Request[] memory studentReqs = new Request[](requestIds.length);

        for (uint256 i = 0; i < requestIds.length; i++) {
            studentReqs[i] = requests[requestIds[i]];
        }
        return studentReqs;
    }

    function getClientRequests() public view returns (Request[] memory) {
        uint256[] storage requestIds = clientRequests[msg.sender];
        Request[] memory clientReqs = new Request[](requestIds.length);

        for (uint256 i = 0; i < requestIds.length; i++) {
            clientReqs[i] = requests[requestIds[i]];
        }
        return clientReqs;
    }
}





// contract Delance {
//     address public owner;

//     // Struct to store student information
//     struct Student {
//         uint256 studentId; // Unique ID for each student
//         address studentAddress;
//         string pseudonym;
//         string skills;
//         uint256 priceInWei; // Price in Wei
//         bool isAvailable;
//     }

//     struct Request {
//         address client;
//         address studentAddress; // Use student address instead of ID
//         uint256 amount; // Amount in Wei
//         bool isAccepted;
//         bool isDisputeRaised;
//         bool isWorkConfirmed;
//         string contactInfo;
//     }

//     mapping(address => bool) public isClient;
//     mapping(uint256 => Student) public studentsById; // Fetch student by ID
//     mapping(uint256 => Request) public requests; // Request mapping using request ID
//     uint256 public requestCounter;
//     uint256 public studentCounter; // To generate unique student IDs
//     mapping(address => uint256) public studentIdsByAddress; // Fetch student ID by address

//     address[] public studentAddresses; // Store the list of student addresses

//     modifier onlyOwner() {
//         require(msg.sender == owner, "Only the contract owner can perform this action");
//         _;
//     }

//     modifier onlyClient() {
//         require(isClient[msg.sender], "You must be a registered client");
//         _;
//     }

//     modifier onlyStudent(uint256 _studentId) {
//         require(studentIdsByAddress[msg.sender] == _studentId, "You are not the student for this request");
//         _;
//     }

//     modifier onlyConcernedParties(uint256 _requestId) {
//         Request storage request = requests[_requestId];
//         require(msg.sender == request.client || msg.sender == request.studentAddress, "You are not authorized to view this request");
//         _;
//     }

//     event RegisteredAsClient(address client);
//     event RegisteredAsStudent(uint256 studentId, address studentAddress, string pseudonym, string skills, uint256 priceInWei);
//     event ServiceRequested(uint256 requestId, address client, address studentAddress, uint256 amount);
//     event RequestAccepted(uint256 requestId, string contactInfo);
//     event RequestRejected(uint256 requestId);
//     event WorkConfirmed(uint256 requestId);
//     event DisputeRaised(uint256 requestId);
//     event DisputeResolved(uint256 requestId, bool clientWins);
//     event StudentUpdated(uint256 studentId, string pseudonym, string skills, uint256 priceInWei);
//     event StudentDeleted(uint256 studentId);

//     constructor() {
//         owner = msg.sender;
//     }

//     // Function to register as a client
//     function registerAsClient() public {
//         require(!isClient[msg.sender], "Already registered as a client");
//         isClient[msg.sender] = true;
//         emit RegisteredAsClient(msg.sender);
//     }

//     // Function to register as a student (creates a unique student ID)
//     function registerAsStudent(string memory _pseudonym, string memory _skills, uint256 _priceInWei) public {
//         require(studentIdsByAddress[msg.sender] == 0, "Already registered as a student");
//         studentCounter++; // Generate new student ID
//         studentsById[studentCounter] = Student(studentCounter, msg.sender, _pseudonym, _skills, _priceInWei, true);
//         studentAddresses.push(msg.sender); // Add student address to list
//         studentIdsByAddress[msg.sender] = studentCounter; // Link address to student ID
//         emit RegisteredAsStudent(studentCounter, msg.sender, _pseudonym, _skills, _priceInWei);
//     }

//     // Function to update student's listing details
//     function updateStudentDetails(uint256 _studentId, string memory _pseudonym, string memory _skills, uint256 _priceInWei) public onlyStudent(_studentId) {
//         Student storage student = studentsById[_studentId];
//         student.pseudonym = _pseudonym;
//         student.skills = _skills;
//         student.priceInWei = _priceInWei;
//         emit StudentUpdated(_studentId, _pseudonym, _skills, _priceInWei);
//     }

//     // Function to delete student's listing (set as unavailable)
//     function deleteStudentListing(uint256 _studentId) public onlyStudent(_studentId) {
//         Student storage student = studentsById[_studentId];
//         student.isAvailable = false; // Mark the student as unavailable
//         emit StudentDeleted(_studentId);
//     }

//     // Function to view all registered students
//     function viewStudents() public view returns (Student[] memory) {
//         Student[] memory allStudents = new Student[](studentCounter);
//         for (uint256 i = 1; i <= studentCounter; i++) {
//             allStudents[i - 1] = studentsById[i];
//         }
//         return allStudents;
//     }

//     // Function for client to request a service from a student by ID
//     function requestService(uint256 _studentId) public payable onlyClient {
//         require(studentsById[_studentId].studentAddress != address(0), "Student not registered");
//         require(studentsById[_studentId].isAvailable, "Student is not available");

//         uint256 amountInWei = studentsById[_studentId].priceInWei;

//         require(msg.value >= amountInWei, "Insufficient payment");

//         requestCounter++;
//         requests[requestCounter] = Request(msg.sender, studentsById[_studentId].studentAddress, msg.value, false, false, false, "");

//         emit ServiceRequested(requestCounter, msg.sender, studentsById[_studentId].studentAddress, msg.value);
//     }

//     // Student accepts the request and contact info is shared with the client
//     function acceptRequest(uint256 _requestId, string memory _contactInfo) public onlyConcernedParties(_requestId) {
//         Request storage request = requests[_requestId];
//         require(!request.isAccepted, "Request already accepted");

//         request.isAccepted = true;
//         request.contactInfo = _contactInfo;
//         emit RequestAccepted(_requestId, _contactInfo);
//     }

//     // Student rejects the request and payment is refunded to the client
//     function rejectRequest(uint256 _requestId) public onlyConcernedParties(_requestId) {
//         Request storage request = requests[_requestId];
//         require(!request.isAccepted, "Request already accepted");

//         address client = request.client;
//         uint256 amount = request.amount;
//         delete requests[_requestId];

//         payable(client).transfer(amount);
//         emit RequestRejected(_requestId);
//     }

//     // Client confirms work is completed and funds are released to the student
//     function confirmWork(uint256 _requestId) public onlyConcernedParties(_requestId) {
//         Request storage request = requests[_requestId];
//         require(request.isAccepted, "Request not yet accepted");
//         require(!request.isWorkConfirmed, "Work already confirmed");

//         request.isWorkConfirmed = true;
//         address student = request.studentAddress;
//         uint256 amount = request.amount;

//         payable(student).transfer(amount);
//         emit WorkConfirmed(_requestId);
//     }

//     // Either party can raise a dispute if there is disagreement
//     function raiseDispute(uint256 _requestId) public onlyConcernedParties(_requestId) {
//         Request storage request = requests[_requestId];
//         require(request.isAccepted, "Request not yet accepted");
//         require(!request.isWorkConfirmed, "Work already confirmed");
//         require(!request.isDisputeRaised, "Dispute already raised");

//         request.isDisputeRaised = true;
//         emit DisputeRaised(_requestId);
//     }

//     // Contract owner resolves the dispute and decides the outcome
//     function resolveDispute(uint256 _requestId, bool clientWins) public onlyOwner {
//         Request storage request = requests[_requestId];
//         require(request.isDisputeRaised, "No dispute to resolve");

//         address client = request.client;
//         address student = request.studentAddress;
//         uint256 amount = request.amount;

//         if (clientWins) {
//             payable(client).transfer(amount); // Refund to client
//         } else {
//             payable(student).transfer(amount); // Payment to student
//         }

//         delete requests[_requestId]; // Dispute resolved, request closed
//         emit DisputeResolved(_requestId, clientWins);
//     }
// }
